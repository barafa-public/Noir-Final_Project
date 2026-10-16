import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppConfig.load(); // baca .env

    // SQLite hanya didukung di Android/iOS. Di Windows/Linux/Web, melewati langkah
    // ini agar tampilan (login/register) tetap bisa dicoba. Fitur yang butuh
    // database akan menampilkan pesan yang jelas (lihat AppDatabase).
    if (AppDatabase.isSupported) {
      await AppDatabase
          .instance
          .database; // buat/buka SQLite (onCreate jalan sekali)
    } else {
      debugPrint(
        'PERINGATAN: SQLite dilewati di platform ini. '
        'Jalankan di emulator/HP Android atau iOS untuk fitur lengkap.',
      );
    }
  } catch (e) {
    runApp(StartupErrorApp(message: e.toString()));
    return;
  }

  // ApiClient/AuthService dibuat malas saat pertama dipakai, setelah AppConfig.load().
  runApp(const NoirApp());
}
