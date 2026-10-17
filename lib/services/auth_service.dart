import 'dart:async';

import 'package:dio/dio.dart';

import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

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
    return _saveSession(res);
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

  /// Hapus token lokal lebih dulu (selalu berhasil), pencabutan di server
  /// dilakukan best-effort tanpa menahan UI.
  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    await _tokens.clear();
    if (refresh != null) unawaited(_revokeRemote(refresh));
  }

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