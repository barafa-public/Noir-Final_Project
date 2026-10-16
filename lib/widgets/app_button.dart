import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Tombol utama: kuning, teks hitam, selebar layar. Saat [loading] tombol
/// nonaktif dan menampilkan indikator, sehingga tidak bisa ditekan dua kali.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.yellow,
          foregroundColor: AppColors.black,
          disabledBackgroundColor: AppColors.yellow.withValues(alpha: 0.6),
          disabledForegroundColor: AppColors.black,
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.black,
                ),
              )
            : Text(label),
      ),
    );
  }
}
