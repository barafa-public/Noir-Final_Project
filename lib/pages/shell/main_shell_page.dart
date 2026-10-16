import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_page.dart';

/// SEMENTARA: hanya bukti bahwa login berhasil dan sarana uji ulang login.
/// Akan digantikan bottom navigation 4 tab (PBI-04.1) dan dialog logout (PBI-04.4).
class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.user});

  final UserModel user;

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.yellow,
                  size: 72,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Login berhasil',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${user.username} (${user.role})',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                OutlinedButton(
                  onPressed: () => _logout(context),
                  child: const Text('Keluar (sementara)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
