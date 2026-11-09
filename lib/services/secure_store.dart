import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pequeno wrapper sobre o flutter_secure_storage com as chaves usadas
/// pelo app (credenciais do app Bling e tokens OAuth2).
class SecureStore {
  SecureStore._();
  static final SecureStore instance = SecureStore._();

  final _storage = const FlutterSecureStorage();

  static const _kClientId = 'bling_client_id';
  static const _kClientSecret = 'bling_client_secret';
  static const _kAccessToken = 'bling_access_token';
  static const _kRefreshToken = 'bling_refresh_token';
  static const _kExpiresAt = 'bling_expires_at';
  static const _kPrinterName = 'printer_name';

  Future<void> saveCredentials(String clientId, String clientSecret) async {
    await _storage.write(key: _kClientId, value: clientId);
    await _storage.write(key: _kClientSecret, value: clientSecret);
  }

  Future<(String, String)?> readCredentials() async {
    final id = await _storage.read(key: _kClientId);
    final secret = await _storage.read(key: _kClientSecret);
    if (id == null || secret == null) return null;
    return (id, secret);
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(
      key: _kExpiresAt,
      value: expiresAt.toIso8601String(),
    );
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);

  Future<DateTime?> get expiresAt async {
    final v = await _storage.read(key: _kExpiresAt);
    if (v == null) return null;
    return DateTime.tryParse(v);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiresAt);
  }

  Future<void> savePrinterName(String name) async {
    await _storage.write(key: _kPrinterName, value: name);
  }

  Future<String?> get printerName => _storage.read(key: _kPrinterName);
}
