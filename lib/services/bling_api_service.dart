import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'bling_auth_service.dart';

/// Busca produtos na API v3 do Bling. A API limita a ~3 requisições por
/// segundo, então aqui espaçamos as chamadas de paginação e, se mesmo assim
/// vier 429 (limite excedido), espera e tenta de novo em vez de abortar a
/// sincronização inteira.
class BlingApiService {
  BlingApiService._();
  static final BlingApiService instance = BlingApiService._();

  static const _baseUrl = 'https://api.bling.com.br/Api/v3';
  static const _pageDelay = Duration(milliseconds: 500);
  static const _maxRetries = 5;

  /// Baixa todos os produtos ativos, página por página.
  Future<List<Product>> fetchAllProducts({void Function(int fetched)? onProgress}) async {
    final products = <Product>[];
    var page = 1;
    while (true) {
      final pageItems = await _fetchPageWithRetry(page);
      if (pageItems.isEmpty) break;
      products.addAll(pageItems);
      onProgress?.call(products.length);
      page++;
      await Future.delayed(_pageDelay);
    }
    return products;
  }

  Future<List<Product>> _fetchPageWithRetry(int page) async {
    var attempt = 0;
    while (true) {
      try {
        return await _fetchPage(page);
      } on _RateLimitException catch (e) {
        attempt++;
        if (attempt > _maxRetries) {
          throw Exception('Limite de requisições do Bling excedido várias vezes seguidas. Tente novamente em alguns minutos.');
        }
        final wait = e.retryAfter ?? Duration(seconds: 2 * attempt);
        await Future.delayed(wait);
      }
    }
  }

  Future<List<Product>> _fetchPage(int page) async {
    final token = await BlingAuthService.instance.getValidAccessToken();
    final uri = Uri.parse('$_baseUrl/produtos').replace(queryParameters: {
      'pagina': '$page',
      'limite': '100',
      'situacao': 'A',
    });

    final response = await http.get(uri, headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    if (response.statusCode == 429) {
      final retryAfterHeader = response.headers['retry-after'];
      final seconds = retryAfterHeader != null ? int.tryParse(retryAfterHeader) : null;
      throw _RateLimitException(seconds != null ? Duration(seconds: seconds) : null);
    }

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar produtos no Bling (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (json['data'] as List?) ?? const [];
    return data
        .cast<Map<String, dynamic>>()
        .map(Product.fromBlingJson)
        .toList();
  }
}

class _RateLimitException implements Exception {
  final Duration? retryAfter;
  _RateLimitException(this.retryAfter);
}
