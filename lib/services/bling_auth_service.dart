import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:url_launcher/url_launcher.dart';

import 'secure_store.dart';

/// Porta local usada para receber o redirect do OAuth2 do Bling.
/// Precisa ser exatamente a mesma cadastrada no app do Bling como
/// Redirect URI: http://localhost:17432/callback
const blingRedirectPort = 17432;
const blingRedirectUri = 'http://localhost:$blingRedirectPort/callback';

const _authorizeUrl = 'https://www.bling.com.br/Api/v3/oauth/authorize';
const _tokenUrl = 'https://api.bling.com.br/Api/v3/oauth/token';

class BlingAuthException implements Exception {
  final String message;
  BlingAuthException(this.message);
  @override
  String toString() => 'BlingAuthException: $message';
}

/// Gerencia o login OAuth2 com o Bling e a renovação automática do token.
class BlingAuthService {
  BlingAuthService._();
  static final BlingAuthService instance = BlingAuthService._();

  final _store = SecureStore.instance;

  Future<bool> hasCredentials() async => (await _store.readCredentials()) != null;

  Future<bool> isLoggedIn() async => (await _store.refreshToken) != null;

  Future<void> saveAppCredentials(String clientId, String clientSecret) =>
      _store.saveCredentials(clientId, clientSecret);

  /// Abre o navegador do sistema para o usuário autorizar o app, aguarda o
  /// redirect em um servidor HTTP local e troca o código pelos tokens.
  Future<void> login() async {
    final creds = await _store.readCredentials();
    if (creds == null) {
      throw BlingAuthException('Configure o Client ID e Client Secret do Bling primeiro.');
    }
    final (clientId, clientSecret) = creds;

    final state = _randomState();
    final authUri = Uri.parse(_authorizeUrl).replace(queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'state': state,
    });

    final codeCompleter = _CallbackServer();
    await codeCompleter.start();

    final opened = await launchUrl(authUri, mode: LaunchMode.externalApplication);
    if (!opened) {
      await codeCompleter.stop();
      throw BlingAuthException('Não foi possível abrir o navegador para login.');
    }

    final String code;
    try {
      code = await codeCompleter.waitForCode(state);
    } finally {
      await codeCompleter.stop();
    }

    await _exchangeCodeForTokens(clientId, clientSecret, code);
  }

  Future<void> _exchangeCodeForTokens(
    String clientId,
    String clientSecret,
    String code,
  ) async {
    final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic $basicAuth',
      },
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': blingRedirectUri,
      },
    );

    if (response.statusCode != 200) {
      throw BlingAuthException('Falha ao trocar código por token: ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _persistTokenResponse(json);
  }

  Future<void> _persistTokenResponse(Map<String, dynamic> json) async {
    final accessToken = json['access_token'] as String;
    final refreshToken = json['refresh_token'] as String;
    final expiresIn = (json['expires_in'] as num).toInt();
    await _store.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Retorna um access token válido, renovando com o refresh token se
  /// estiver vencido ou perto de vencer.
  Future<String> getValidAccessToken() async {
    final expiresAt = await _store.expiresAt;
    final accessToken = await _store.accessToken;
    if (accessToken != null &&
        expiresAt != null &&
        expiresAt.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return accessToken;
    }
    return _refreshAccessToken();
  }

  Future<String> _refreshAccessToken() async {
    final creds = await _store.readCredentials();
    final refreshToken = await _store.refreshToken;
    if (creds == null || refreshToken == null) {
      throw BlingAuthException('Não há sessão salva. Faça login novamente.');
    }
    final (clientId, clientSecret) = creds;

    final basicAuth = base64Encode(utf8.encode('$clientId:$clientSecret'));
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Authorization': 'Basic $basicAuth',
      },
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      await _store.clearTokens();
      throw BlingAuthException('Sessão expirada. Faça login novamente.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    await _persistTokenResponse(json);
    return json['access_token'] as String;
  }

  Future<void> logout() => _store.clearTokens();

  String _randomState() {
    final rnd = Random.secure();
    return base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
  }
}

/// Servidor HTTP local efêmero só para capturar o redirect do OAuth2.
class _CallbackServer {
  HttpServer? _server;
  final _codeCompleter = Completer<String>();

  Future<void> start() async {
    final handler = Pipeline().addHandler(_handle);
    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, blingRedirectPort);
  }

  Response _handle(Request request) {
    final code = request.url.queryParameters['code'];
    final state = request.url.queryParameters['state'];
    final error = request.url.queryParameters['error'];

    if (!_codeCompleter.isCompleted) {
      if (error != null) {
        _codeCompleter.completeError(BlingAuthException('Bling retornou erro: $error'));
      } else if (code != null) {
        _codeCompleter.complete('$code|$state');
      }
    }

    return Response.ok(
      '<html><body><h3>Login concluído. Pode voltar para o app.</h3></body></html>',
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }

  Future<String> waitForCode(String expectedState) async {
    final result = await _codeCompleter.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw BlingAuthException('Tempo esgotado esperando o login.'),
    );
    final parts = result.split('|');
    final code = parts[0];
    final state = parts.length > 1 ? parts[1] : null;
    if (state != expectedState) {
      throw BlingAuthException('State inválido no retorno do login (possível CSRF).');
    }
    return code;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}
