import 'package:flutter/material.dart';

/// Palet Noir. Empat warna pertama berasal dari dokumen warna proyek;
/// sisanya turunan untuk latar gelap.
class AppColors {
  AppColors._();

  // Dokumen warna
  static const Color black = Color(0xFF0D0D0D);
  static const Color yellow = Color(0xFFFDC40B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFFD9D9D9);

  // Turunan (latar gelap)
  static const Color surface = Color(0xFF1A1A1A); // kartu / isian di atas hitam
  static const Color border = Color(0xFF3A3A3A);
  static const Color textSecondary = Color(0xFFA6A6A6);

  // Semantik (status)
  static const Color success = Color(0xFF4CD08A);
  static const Color error = Color(0xFFFF6B6B);
}
