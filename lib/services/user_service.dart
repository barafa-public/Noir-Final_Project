import 'dart:convert';
import 'dart:typed_data';

import '../models/user_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

/// Profil pengguna. Kontrak Edge Function:
///
/// POST users/me              {}              -> 200 {id, username, role, nama, alamat, telepon, foto_url, biometric_enabled}
/// POST users/update-profile  {nama}          -> 200 (bentuk sama dengan me)
/// POST uploads/avatar        {image_base64}  -> 200 {foto_url}
///
/// `foto_url` dari users/me adalah tautan sementara (berlaku sekitar 1 jam).
/// `foto_url` dari auth/login adalah path penyimpanan, JANGAN ditampilkan.
class UserService {
  UserService._();

  static final UserService instance = UserService._();

  ApiClient get _api => AuthService.instance.api;

  Future<UserModel> getMe() async {
    final res = await _api.send('users/me');
    return _parse(res.data);
  }

  Future<UserModel> updateName(String nama) async {
    final res = await _api.send('users/update-profile', {'nama': nama});
    return _parse(res.data);
  }

  /// Mengunggah foto profil (JPG/PNG/WebP, maksimal 1 MB).
  Future<void> uploadAvatar(Uint8List bytes) async {
    await _api.send('uploads/avatar', {'image_base64': base64Encode(bytes)});
  }

  UserModel _parse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    try {
      return UserModel.fromJson(data);
    } catch (_) {
      throw ApiException('Data pengguna dari server tidak valid.');
    }
  }
}
