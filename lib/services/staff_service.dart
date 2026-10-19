import '../models/staff_model.dart';
import 'api_client.dart';
import 'api_exception.dart';
import 'auth_service.dart';

/// Kelola akun Staff Gudang. Hanya berhasil untuk role Manager: server menjawab 403
/// untuk role lain, jadi pembatasan tidak bergantung pada tampilan menu.
class StaffService {
  StaffService._();

  static final StaffService instance = StaffService._();

  ApiClient get _api => AuthService.instance.api;

  Future<List<StaffModel>> list() async {
    final res = await _api.send('users/staff-list');
    final data = res.data;
    if (data is! Map<String, dynamic> || data['staff'] is! List) {
      throw ApiException('Respons server tidak valid.');
    }
    try {
      return (data['staff'] as List)
          .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw ApiException('Data staff dari server tidak valid.');
    }
  }

  Future<StaffModel> create({
    required String username,
    required String nama,
    required String password,
  }) async {
    final res = await _api.send('users/staff-create', {
      'username': username,
      'nama': nama,
      'password': password,
    });
    return _one(res.data);
  }

  /// Hanya field yang diberikan yang dikirim.
  /// - [isActive] false : akun dinonaktifkan dan semua sesinya dicabut
  /// - [password]       : password diganti, semua sesinya dicabut
  Future<StaffModel> update(
    int id, {
    String? nama,
    bool? isActive,
    String? password,
  }) async {
    final body = <String, dynamic>{'id': id};
    if (nama != null) body['nama'] = nama;
    if (isActive != null) body['is_active'] = isActive;
    if (password != null) body['password'] = password;

    final res = await _api.send('users/staff-update', body);
    return _one(res.data);
  }

  StaffModel _one(dynamic data) {
    if (data is! Map<String, dynamic> ||
        data['staff'] is! Map<String, dynamic>) {
      throw ApiException('Respons server tidak valid.');
    }
    try {
      return StaffModel.fromJson(data['staff'] as Map<String, dynamic>);
    } catch (_) {
      throw ApiException('Data staff dari server tidak valid.');
    }
  }
}
