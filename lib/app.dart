import 'package:flutter/material.dart';

import 'pages/auth/login_page.dart';
import 'theme/app_theme.dart';

class NoirApp extends StatelessWidget {
  const NoirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noir',
      theme: AppTheme.dark,
      // TODO PBI-01.3/02: ganti dengan SplashPage (cek token, refresh, biometrik).
      home: const LoginPage(),
    );
  }
}

/// Ditampilkan jika .env kosong/salah atau SQLite gagal dibuka.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('Gagal memulai aplikasi:\n$message')),
        ),
      ),
    );
  }
}
