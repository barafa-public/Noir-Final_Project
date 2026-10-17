import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Logo Noir versi putih (untuk latar gelap). Logo asli berhuruf hitam
/// sehingga tidak terlihat di atas hitam.
class NoirLogo extends StatelessWidget {
  const NoirLogo({super.key, this.width = 220});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo_noir_white.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Logo Noir',
      // Jika asset belum dipasang/didaftarkan, tampilkan teks yang menyesuaikan lebar.
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: width,
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'NOIR',
            style: TextStyle(
              color: AppColors.yellow,
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}
