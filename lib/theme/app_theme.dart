import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.yellow,
      onPrimary: AppColors
          .black, // teks/ikon di atas kuning HARUS hitam (kontras ~12:1)
      surface: AppColors.black,
      onSurface: AppColors.white,
      error: AppColors.error,
      onError: AppColors.black,
    );

    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.black,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.yellow,
        selectionHandleColor: AppColors.yellow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        errorStyle: const TextStyle(color: AppColors.error),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        focusedBorder: border(AppColors.yellow, 1.5),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error, 1.5),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.yellow),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: AppColors.yellow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.black : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.yellow : AppColors.textSecondary,
          );
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
