import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../widgets/menu_card.dart';
import 'biometric_settings_page.dart';

/// Sementara hanya memuat pengaturan keamanan. Foto, nama, dan data akun
/// menyusul di Batch C (PBI-04.2).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          const Text(
            'Profil',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Keamanan',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          MenuCard(
            title: 'Login Biometrik',
            icon: Icons.fingerprint_rounded,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BiometricSettingsPage(user: user),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Foto, nama, dan data akun akan tersedia di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}