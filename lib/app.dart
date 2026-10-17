import 'package:flutter/material.dart';

import 'pages/auth/login_page.dart';
import 'pages/auth/splash_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

/// Dipakai untuk berpindah halaman dari luar widget (mis. saat sesi berakhir).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class NoirApp extends StatefulWidget {
  const NoirApp({super.key});

  @override
  State<NoirApp> createState() => _NoirAppState();
}

class _NoirAppState extends State<NoirApp> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.onSessionExpired = _onSessionExpired;
  }

  @override
  void dispose() {
    AuthService.instance.onSessionExpired = null;
    super.dispose();
  }

  /// Refresh token ditolak server: hapus semua halaman, kembali ke Login.
  void _onSessionExpired() {
    rootNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) =>
            const LoginPage(notice: 'Sesi berakhir. Silakan masuk lagi.'),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Noir',
      theme: AppTheme.dark,
      home: const SplashPage(),
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
