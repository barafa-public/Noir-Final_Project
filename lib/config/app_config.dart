import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Membaca konfigurasi dari .env (BACKEND_URL, BACKEND_PUBLISHABLE_KEY).
/// Panggil [AppConfig.load] sekali di main() sebelum runApp.
class AppConfig {
  AppConfig._();

  static String _backendUrl = '';
  static String _publishableKey = '';

  /// Contoh: https://abcd1234.supabase.co
  static String get backendUrl => _backendUrl;

  /// Kunci publik (sb_publishable_...). Bukan rahasia.
  static String get publishableKey => _publishableKey;

  /// Basis URL Edge Functions: <BACKEND_URL>/functions/v1
  static String get functionsUrl => '$_backendUrl/functions/v1';

  static Future<void> load() async {
    await dotenv.load(fileName: '.env');

    final url = _require('BACKEND_URL').replaceAll(RegExp(r'/+$'), '');
    if (!url.startsWith('https://')) {
      throw StateError('BACKEND_URL harus diawali https:// (HTTPS wajib).');
    }

    _backendUrl = url;
    _publishableKey = _require('BACKEND_PUBLISHABLE_KEY');
  }

  static String _require(String key) {
    final value = dotenv.env[key]?.trim() ?? '';
    if (value.isEmpty) {
      throw StateError('$key kosong. Isi di file .env (lihat .env.example).');
    }
    return value;
  }
}
