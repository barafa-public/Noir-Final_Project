import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Dialog konfirmasi Ya/Batal. Mengembalikan true hanya jika pengguna menekan
/// tombol konfirmasi (menutup dialog dengan cara lain = false).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Ya',
  String cancelLabel = 'Batal',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          style: TextButton.styleFrom(foregroundColor: AppColors.white),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.black,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
