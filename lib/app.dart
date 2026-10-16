import 'package:flutter/material.dart';

class NoirApp extends StatelessWidget {
  const NoirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noir',
      // TODO: ganti dengan penentuan halaman awal (login / shell) berdasarkan sesi
      home: Scaffold(body: Center(child: Text('Noir'))),
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
