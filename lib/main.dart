import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'database/app_database.dart';
import 'services/api_client.dart';

late final ApiClient api;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await AppConfig.load();               // baca .env
    await AppDatabase.instance.database;  // buat/buka SQLite (onCreate jalan sekali)
  } catch (e) {
    runApp(StartupErrorApp(message: e.toString()));
    return;
  }

  api = ApiClient();                      // harus setelah AppConfig.load()
  runApp(const NoirApp());
}
