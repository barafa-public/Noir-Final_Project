import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Token JWT hanya disimpan di Keystore/Keychain (flutter_secure_storage),
/// TIDAK PERNAH di SQLite atau SharedPreferences.
///
/// Penanda "biometrik aktif di perangkat ini" juga disimpan di sini dan ikut
/// terhapus oleh [clear]: sesi berakhir/logout otomatis mematikan login biometrik,
/// sehingga tidak ada penanda yang tertinggal tanpa sesi.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const biometricUserKey = 'biometric_user_id';

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: accessTokenKey, value: accessToken);
    await _storage.write(key: refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccess() => _storage.read(key: accessTokenKey);

  Future<String?> readRefresh() => _storage.read(key: refreshTokenKey);

  /// Id pengguna yang mengaktifkan biometrik di perangkat ini (null = tidak aktif).
  Future<int?> readBiometricUser() async {
    final value = await _storage.read(key: biometricUserKey);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> setBiometricUser(int userId) =>
      _storage.write(key: biometricUserKey, value: userId.toString());

  Future<void> clearBiometric() => _storage.delete(key: biometricUserKey);

  Future<void> clear() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
    await _storage.delete(key: biometricUserKey);
  }
}