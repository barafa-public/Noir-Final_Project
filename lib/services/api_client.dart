import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'token_storage.dart';

enum _RefreshResult {
  ok, // token baru tersimpan
  rejected, // server menolak refresh token -> sesi benar-benar berakhir
  unavailable, // jaringan/server bermasalah -> JANGAN logout
}

/// Klien HTTP ke Edge Functions Supabase.
///
/// - Menambahkan header `Authorization: Bearer <access token>` ke setiap permintaan.
/// - Jika server menjawab 401 untuk permintaan yang membawa token, otomatis mencoba
///   refresh token SATU kali, lalu mengulang permintaan semula.
/// - Jika refresh ditolak, token dihapus dan [onSessionExpired] dipanggil (logout).
///
/// Header `apikey` hanya mengidentifikasi proyek, BUKAN perlindungan. Otorisasi
/// sebenarnya = JWT buatan sendiri yang diverifikasi di server.
class ApiClient {
  ApiClient({required TokenStorage tokens})
      : _tokens = tokens,
        dio = _newDio(),
        _plain = _newDio() {
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  static Dio _newDio() {
    return Dio(BaseOptions(
      baseUrl: AppConfig.functionsUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'apikey': AppConfig.publishableKey,
        'Content-Type': 'application/json',
      },
    ));
  }

  final TokenStorage _tokens;

  /// Dio utama (dengan interceptor).
  final Dio dio;

  /// Dio polos tanpa interceptor, khusus untuk memanggil auth/refresh
  /// (mencegah perulangan tak berujung).
  final Dio _plain;

  /// Dipanggil sekali ketika sesi berakhir dan pengguna harus masuk lagi.
  void Function()? onSessionExpired;

  Future<_RefreshResult>? _refreshing;
  bool _expiredFired = false;

  /// Contoh: await api.post('auth/login', {'username': u, 'password': p});
  /// -> POST <BACKEND_URL>/functions/v1/auth/login
  Future<Response<dynamic>> post(String function, Map<String, dynamic> body) =>
      dio.post('/$function', data: body);

  // ---------------------------------------------------------------- interceptor

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokens.readAccess();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
      _expiredFired = false; // sudah ada sesi lagi (mis. setelah login ulang)
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final request = error.requestOptions;
    final isAuthCall = request.path.startsWith('/auth/');
    final hadToken = request.headers['Authorization'] != null;
    final alreadyRetried = request.extra['retried'] == true;

    // 401 pada login/register berarti "kredensial salah", bukan token kedaluwarsa.
    if (error.response?.statusCode != 401 ||
        isAuthCall ||
        !hadToken ||
        alreadyRetried) {
      handler.next(error);
      return;
    }

    switch (await _refreshTokens()) {
      case _RefreshResult.ok:
        try {
          request.extra['retried'] = true;
          final response = await dio.fetch<dynamic>(request);
          handler.resolve(response);
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      case _RefreshResult.rejected:
        if (!_expiredFired) {
          _expiredFired = true;
          await _tokens.clear();
          onSessionExpired?.call();
        }
        handler.next(error);
      case _RefreshResult.unavailable:
        handler.next(error);
    }
  }

  /// Beberapa permintaan yang gagal 401 bersamaan hanya memicu SATU refresh.
  /// (Refresh token dirotasi server; dua refresh paralel akan saling mematikan.)
  Future<_RefreshResult> _refreshTokens() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<_RefreshResult> _doRefresh() async {
    final refresh = await _tokens.readRefresh();
    if (refresh == null || refresh.isEmpty) return _RefreshResult.rejected;

    try {
      final res = await _plain.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = res.data;
      if (data is Map<String, dynamic> &&
          data['access_token'] is String &&
          data['refresh_token'] is String) {
        await _tokens.save(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return _RefreshResult.ok;
      }
      return _RefreshResult.unavailable;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) return _RefreshResult.rejected;
      return _RefreshResult.unavailable;
    }
  }
}