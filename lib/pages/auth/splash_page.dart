import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/noir_logo.dart';
import '../shell/main_shell_page.dart';
import 'login_page.dart';

/// Halaman pertama: memulihkan sesi dari token tersimpan.
/// - Kunci biometrik aktif -> Login dengan prompt biometrik otomatis (aplikasi "terkunci");
/// jika biometrik perangkat tak tersedia, Login meminta password (tidak terbuka otomatis)
/// - Ada sesi valid        -> Beranda
/// - Tidak ada/ditolak     -> Login
/// - Jaringan bermasalah   -> pesan + Coba Lagi (sesi TIDAK dihapus)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      if (await AuthService.instance.isBiometricLockActive()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const LoginPage(autoBiometric: true),
          ),
        );
        return;
      }

      final user = await AuthService.instance.restoreSession();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              user == null ? const LoginPage() : MainShellPage(user: user),
        ),
      );
    } on ApiException {
      if (mounted) {
        setState(() => _error =
            'Tidak dapat memuat sesi. Periksa koneksi internet lalu coba lagi.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga.');
    }
  }

  void _retry() {
    setState(() => _error = null);
    _boot();
  }

  Future<void> _useAnotherAccount() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: NoirLogo(width: 200)),
                  const SizedBox(height: 40),
                  if (_error == null)
                    const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.yellow,
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    AppButton(label: 'Coba Lagi', onPressed: _retry),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _useAnotherAccount,
                      child: const Text('Masuk dengan akun lain'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}