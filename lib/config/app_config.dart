import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Membaca konfigurasi dari .env (BACKEND_URL, BACKEND_PUBLISHABLE_KEY).
/// Panggil [AppConfig.load] sekali di main() sebelum runApp.
class AppConfig {
  AppConfig._();

  static String _backendUrl = '';
  static String _publishableKey = '';

  /// Hanya "origin" proyek, contoh: https://abcd1234.supabase.co
  /// (tanpa /rest/v1, /functions/v1, atau path lain).
  static String get backendUrl => _backendUrl;

  /// Kunci publik (sb_publishable_...). Bukan rahasia.
  static String get publishableKey => _publishableKey;

  /// Basis URL Edge Functions: <BACKEND_URL>/functions/v1
  static String get functionsUrl => '$_backendUrl/functions/v1';

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');

    final raw = _require('BACKEND_URL');
    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException {
      throw StateError('BACKEND_URL bukan alamat yang valid.');
    }
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw StateError(
        'BACKEND_URL harus berupa https://<project-ref>.supabase.co',
      );
    }

    // Ambil hanya scheme + host. Path yang ikut tersalin dari dashboard
    // (mis. /rest/v1/) dibuang, karena aplikasi menambahkan /functions/v1 sendiri.
    if (kDebugMode && uri.path.isNotEmpty && uri.path != '/') {
      debugPrint(
        'PERINGATAN: BACKEND_URL berisi path "${uri.path}". '
        'Path diabaikan; isi .env sebaiknya hanya https://<project-ref>.supabase.co',
      );
    }
    _backendUrl = uri.origin;
    _publishableKey = _require('BACKEND_PUBLISHABLE_KEY');
  }

  static String _require(String key) {
    final value = dotenv.env[key]?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('$key kosong. Isi di file .env.');
    }
    return value;
  }
}
