import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../auth/login_page.dart';
import '../feedback/feedback_page.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';

/// Kerangka setelah login: bottom navigation 4 tab (Beranda, Profil, Saran & Kesan,
/// Logout). Logout bukan halaman: menekannya membuka dialog konfirmasi.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.user});

  final UserModel user;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  static const _logoutIndex = 3;

  late UserModel _user;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  /// Dipanggil Profil saat data berubah (nama/foto), agar Beranda ikut diperbarui.
  void _onUserChanged(UserModel user) {
    if (mounted) setState(() => _user = user);
  }

  Future<void> _confirmLogout() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Keluar dari Noir?',
      message: 'Anda harus masuk lagi untuk mengakses akun ini.',
      confirmLabel: 'Keluar',
    );
    if (!ok || !mounted) return;

    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  void _onSelected(int i) {
    if (i == _logoutIndex) {
      _confirmLogout(); // tab tidak berpindah
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomePage(user: _user),
          ProfilePage(user: _user, onUserChanged: _onUserChanged),
          const FeedbackPage(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
            NavigationDestination(
              icon: Icon(Icons.rate_review_outlined),
              selectedIcon: Icon(Icons.rate_review_rounded),
              label: 'Saran & Kesan',
            ),
            NavigationDestination(
              icon: Icon(Icons.logout_rounded),
              label: 'Logout',
            ),
          ],
        ),
      ),
    );
  }
}
