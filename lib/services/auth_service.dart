import 'dart:async';

import 'package:dio/dio.dart';

import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// Kontrak Edge Function `auth` (belum dibuat, lihat PBI-01.2):
///
/// POST auth/register  {username, alamat, telepon, password}
///   -> 201 {}                     | 4xx {"error": "..."}
/// POST auth/login     {username, password}
///   -> 200 {access_token, refresh_token, user:{id, username, role, nama, foto_url, biometric_enabled}}
///   -> 401 {"error": "Username atau password salah"}   (pesan SAMA untuk username/password salah)
/// POST auth/logout    {refresh_token}  -> 204
class AuthService {
  AuthService._(this._api, this._tokens);

  /// Dibuat malas (saat pertama dipakai), jadi AppConfig.load() sudah selesai.
  static final AuthService instance = AuthService._(
    ApiClient(),
    TokenStorage(),
  );

  final ApiClient _api;
  final TokenStorage _tokens;

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

    final data = res.data;
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    final access = data['access_token'];
    final refresh = data['refresh_token'];
    final user = data['user'];
    if (access is! String ||
        refresh is! String ||
        user is! Map<String, dynamic>) {
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

  /// Hapus token lokal lebih dulu (selalu berhasil), pencabutan di server
  /// dilakukan best-effort tanpa menahan UI.
  Future<void> logout() async {
    final refresh = await _tokens.readRefresh();
    await _tokens.clear();
    if (refresh != null) unawaited(_revokeRemote(refresh));
  }

  Future<void> _revokeRemote(String refreshToken) async {
    try {
      await _api.post('auth/logout', {'refresh_token': refreshToken});
    } catch (_) {
      // Diabaikan: token lokal sudah dihapus.
    }
  }

  Future<Response<dynamic>> _send(
    String function,
    Map<String, dynamic> body,
  ) async {
    try {
      return await _api.post(function, body);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
