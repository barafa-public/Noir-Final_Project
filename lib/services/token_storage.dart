import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token JWT hanya disimpan di Keystore/Keychain (flutter_secure_storage),
/// TIDAK PERNAH di SQLite atau SharedPreferences.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccess() => _storage.read(key: accessTokenKey);

  Future<String?> readRefresh() => _storage.read(key: refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }
}