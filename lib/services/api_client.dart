import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';

/// Klien HTTP ke Edge Functions Supabase.
/// Buat SETELAH AppConfig.load() selesai.
///
/// Catatan: header `apikey` hanya mengidentifikasi proyek. Edge Function dengan
/// verify_jwt=false tidak memeriksanya, jadi ini BUKAN perlindungan. Otorisasi
/// sebenarnya = JWT buatan sendiri (Authorization: Bearer) yang diverifikasi di server.
class ApiClient {
  ApiClient({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        dio = Dio(BaseOptions(
          baseUrl: AppConfig.functionsUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 20),
          headers: {
            'apikey': AppConfig.publishableKey,
            'Content-Type': 'application/json',
          },
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: accessTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  static const accessTokenKey = 'access_token';

  final FlutterSecureStorage _storage;
  final Dio dio;

  /// Contoh: await api.post('auth-login', {'username': u, 'password': p});
  /// -> POST <BACKEND_URL>/functions/v1/auth-login
  Future<Response<dynamic>> post(String function, Map<String, dynamic> body) =>
      dio.post('/$function', data: body);
}
