import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../widgets/empty_view.dart';

/// Placeholder tab Profil (foto, nama, role, pengaturan biometrik menyusul).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              'Profil',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: EmptyView(
              icon: Icons.person_outline_rounded,
              title: 'Segera hadir',
              message:
                  'Foto, data akun, dan pengaturan biometrik akan ada di sini.',
            ),
          ),
        ],
      ),
    );
  }
}
