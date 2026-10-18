import 'dart:async';

import 'package:dio/dio.dart';

import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'biometric_service.dart';
import 'token_storage.dart';

enum BiometricEnableResult { enabled, unavailable, cancelled }

enum BiometricLoginStatus {
  success,
  cancelled, // gagal/dibatalkan: tawarkan coba lagi atau password
  sessionInvalid, // tidak ada sesi/penanda tidak cocok: wajib password
}

class BiometricLoginResult {
  const BiometricLoginResult(this.status, [this.user]);

  final BiometricLoginStatus status;
  final UserModel? user;
}

/// Kontrak Edge Function `auth`:
///
/// POST auth/register  {username, alamat, telepon, password}      -> 201 {}
/// POST auth/login     {username, password}
///   -> 200 {access_token, refresh_token, expires_in, user:{id, username, role, nama, foto_url, biometric_enabled}}
///   -> 401 {"error": "Username atau password salah"}
/// POST auth/refresh   {refresh_token}  -> 200 (bentuk sama dengan login) | 401
/// POST auth/logout    {refresh_token}  -> 204
class AuthService {
  AuthService._(TokenStorage tokens)
      : _tokens = tokens,
        _api = ApiClient(tokens: tokens) {
    _api.onSessionExpired = () => onSessionExpired?.call();
  }

  /// Dibuat malas (saat pertama dipakai), jadi AppConfig.load() sudah selesai.
  static final AuthService instance = AuthService._(TokenStorage());

  final TokenStorage _tokens;
  final ApiClient _api;
  final BiometricService _biometrics = BiometricService();

  /// Klien HTTP bersama (sudah punya refresh token otomatis).
  /// Semua service lain WAJIB memakai ini, bukan membuat ApiClient sendiri.
  ApiClient get api => _api;

  /// Dipasang oleh NoirApp: dipanggil saat sesi berakhir dan perlu kembali ke Login.
  void Function()? onSessionExpired;

  Future<void> register({
    required String username,
    required String alamat,
    required String telepon,
    required String password,
  }) async {
    await _send('auth/register', {
      'username': username,
      'alamat': alamat,
      'telepon': telepon,
      'password': password,
    });
  }

  Future<UserModel> login({
    required String username,
    required String password,
  }) async {
    final res = await _send('auth/login', {
      'username': username,
      'password': password,
    });
    final user = await _saveSession(res);

    // Penanda biometrik milik akun lain tidak boleh menempel ke akun ini.
    final biometricUser = await _tokens.readBiometricUser();
    if (biometricUser != null && biometricUser != user.id) {
      await _tokens.clearBiometric();
    }
    return user;
  }

  /// Dipakai saat aplikasi dibuka: memulihkan sesi dari refresh token tersimpan.
  /// Sekaligus mengambil data pengguna terbaru (mis. role yang baru diubah).
  ///
  /// - berhasil           -> UserModel
  /// - tidak ada/ditolak  -> null (token dihapus; arahkan ke Login)
  /// - jaringan/server    -> melempar ApiException (JANGAN logout; tawarkan coba lagi)
  Future<UserModel?> restoreSession() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return null;

    try {
      final res = await _send('auth/refresh', {'refresh_token': refresh});
      return await _saveSession(res);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await _tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Hapus token lokal lebih dulu (selalu berhasil; ikut mematikan biometrik),
  /// pencabutan di server dilakukan best-effort tanpa menahan UI.
  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    await _tokens.clear();
    if (refresh != null) unawaited(_revokeRemote(refresh));
  }

  // ------------------------------------------------------------------ biometrik

  /// "Kunci biometrik" aktif: pengguna mengaktifkannya di perangkat ini dan masih
  /// ada sesi tersimpan. Selama aktif, aplikasi TIDAK boleh terbuka otomatis tanpa
  /// verifikasi, walaupun biometrik perangkat sedang tidak tersedia (mis. sidik jari
  /// dihapus dari pengaturan HP). Dalam kasus itu pengguna wajib masuk dengan password.
  Future<bool> isBiometricLockActive() async {
    if (await _tokens.readBiometricUser() == null) return false;
    final refresh = await _tokens.readRefresh();
    return refresh != null && refresh.isNotEmpty;
  }

  /// Tombol/prompt biometrik hanya ditawarkan jika kunci aktif DAN perangkat
  /// mendukung biometrik yang sudah terdaftar.
  Future<bool> isBiometricLoginReady() async {
    if (!await isBiometricLockActive()) return false;
    return await _biometrics.checkSupport() == BiometricSupport.supported;
  }

  Future<bool> isBiometricEnabledFor(UserModel user) async {
    return await _tokens.readBiometricUser() == user.id;
  }

  /// Mengaktifkan biometrik: pengguna harus lolos verifikasi sekali lebih dulu.
  Future<BiometricEnableResult> enableBiometric(UserModel user) async {
    if (await _biometrics.checkSupport() != BiometricSupport.supported) {
      return BiometricEnableResult.unavailable;
    }
    final ok = await _biometrics.authenticate(
      'Verifikasi untuk mengaktifkan login biometrik',
    );
    if (!ok) return BiometricEnableResult.cancelled;

    await _tokens.setBiometricUser(user.id);
    return BiometricEnableResult.enabled;
  }

  Future<void> disableBiometric() => _tokens.clearBiometric();

  /// Biometrik "membuka" sesi yang sudah tersimpan: setelah lolos verifikasi,
  /// refresh token dipakai untuk memulihkan sesi (dan mengambil data terbaru).
  /// Melempar ApiException jika jaringan/server bermasalah.
  Future<BiometricLoginResult> loginWithBiometric() async {
    final expectedUser = await _tokens.readBiometricUser();
    if (expectedUser == null) {
      return const BiometricLoginResult(BiometricLoginStatus.sessionInvalid);
    }

    final ok = await _biometrics.authenticate('Masuk ke Noir dengan biometrik');
    if (!ok) {
      return const BiometricLoginResult(BiometricLoginStatus.cancelled);
    }

    final user = await restoreSession();
    if (user == null) {
      return const BiometricLoginResult(BiometricLoginStatus.sessionInvalid);
    }
    if (user.id != expectedUser) {
      // Sesi milik akun lain: jangan dipakai.
      await _tokens.clear();
      return const BiometricLoginResult(BiometricLoginStatus.sessionInvalid);
    }
    return BiometricLoginResult(BiometricLoginStatus.success, user);
  }

  // ------------------------------------------------------------------- internal

  Future<UserModel> _saveSession(Response<dynamic> res) async {
    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    final user = data['user'];
    if (access is! String || refresh is! String || user is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }

    final UserModel model;
    try {
      model = UserModel.fromJson(user);
    } catch (_) {
      throw ApiException('Data pengguna dari server tidak valid.');
    }

    await _tokens.save(accessToken: access, refreshToken: refresh);
    return model;
  }

  Future<void> _revokeRemote(String refreshToken) async {
    try {
      await _api.post('auth/logout', {'refresh_token': refreshToken});
    } catch (_) {
      // Diabaikan: token lokal sudah dihapus.
    }
  }

  Future<Response<dynamic>> _send(String function, Map<String, dynamic> body) async {
    try {
      return await _api.post(function, body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}