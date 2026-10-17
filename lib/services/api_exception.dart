import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Error yang sudah diterjemahkan ke pesan yang aman ditampilkan ke pengguna.
///
/// Di mode DEBUG, pesan ditambah detail teknis (alamat yang dipanggil dan error
/// aslinya) agar penyebab masalah jaringan langsung terlihat di layar.
/// Di mode release, detail itu TIDAK ditampilkan.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(DioException e) {
    final base = _translate(e);
    if (!kDebugMode) return base;

    final detail =
        '[debug] ${e.type.name} ${e.requestOptions.method} '
        '${e.requestOptions.uri}\n${e.error ?? e.message ?? '-'}';
    debugPrint('[API] $detail');
    return ApiException(
      '${base.message}\n\n$detail',
      statusCode: base.statusCode,
    );
  }

  /// Kontrak error Edge Function: JSON { "error": "pesan" } dengan status 4xx/5xx.
  static ApiException _translate(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        );
      case DioExceptionType.badResponse:
        {
          final code = e.response?.statusCode;
          final data = e.response?.data;
          if (data is Map && data['error'] is String) {
            return ApiException(data['error'] as String, statusCode: code);
          }
          if (code == 429) {
            return ApiException(
              'Terlalu banyak percobaan. Coba lagi nanti.',
              statusCode: code,
            );
          }
          if (code != null && code >= 500) {
            return ApiException(
              'Terjadi kesalahan pada server. Coba lagi nanti.',
              statusCode: code,
            );
          }
          return ApiException(
            'Permintaan gagal (kode $code).',
            statusCode: code,
          );
        }
      case DioExceptionType.cancel:
        return ApiException('Permintaan dibatalkan.');
      case DioExceptionType.badCertificate:
        return ApiException('Sertifikat keamanan server tidak valid.');
      case DioExceptionType.unknown:
        return ApiException('Terjadi kesalahan tak terduga.');
    }
  }

  @override
  String toString() => message;
}
