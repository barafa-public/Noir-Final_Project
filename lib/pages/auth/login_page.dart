import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/password_field.dart';
import '../shell/main_shell_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  /// [notice]: pesan awal di atas tombol, mis. "Sesi berakhir. Silakan masuk lagi."
  /// [autoBiometric]: langsung menampilkan prompt biometrik saat halaman dibuka.
  const LoginPage({super.key, this.notice, this.autoBiometric = false});

  final String? notice;
  final bool autoBiometric;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _maxBiometricFailures = 3;

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _biometricReady = false;
  bool _biometricBusy = false;
  int _biometricFailures = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
    _checkBiometric();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _checkBiometric() async {
    final locked = await AuthService.instance.isBiometricLockActive();
    final ready = locked && await AuthService.instance.isBiometricLoginReady();
    if (!mounted) return;
    setState(() {
      _biometricReady = ready;
      // Kunci aktif tetapi biometrik perangkat tidak tersedia: wajib password.
      if (locked && !ready && _error == null) {
        _error = 'Biometrik tidak tersedia di perangkat ini. Silakan masuk dengan password.';
      }
    });
    if (ready && widget.autoBiometric) _biometricLogin();
  }

  void _goToShell(UserModel user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => MainShellPage(user: user)),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.instance.login(
        username: _username.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      _goToShell(user);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _biometricLogin() async {
    if (_loading || _biometricBusy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _biometricBusy = true;
      _error = null;
    });

    try {
      final result = await AuthService.instance.loginWithBiometric();
      if (!mounted) return;

      switch (result.status) {
        case BiometricLoginStatus.success:
          _goToShell(result.user!);
        case BiometricLoginStatus.cancelled:
          _biometricFailures++;
          if (_biometricFailures >= _maxBiometricFailures) {
            // Gagal berulang: sembunyikan tombol, arahkan ke password.
            setState(() {
              _biometricReady = false;
              _error = 'Biometrik gagal beberapa kali. Silakan masuk dengan password.';
            });
          } else {
            setState(() => _error =
                'Biometrik gagal atau dibatalkan. Coba lagi atau masuk dengan password.');
          }
        case BiometricLoginStatus.sessionInvalid:
          setState(() {
            _biometricReady = false;
            _error = 'Sesi biometrik berakhir. Silakan masuk dengan password.';
          });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<void> _openRegister() async {
    final username = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const RegisterPage()),
    );
    if (!mounted || username == null) return;
    _username.text = username;
    _password.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registrasi berhasil. Silakan masuk.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _biometricBusy;

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Selamat Datang',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Masuk ke akun Noir Anda',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            AppTextField(
              controller: _username,
              label: 'Username',
              hint: 'Masukkan username',
              icon: Icons.person_outline_rounded,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (v) => Validators.notEmpty(v, 'Username'),
            ),
            const SizedBox(height: 18),
            PasswordField(
              controller: _password,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              validator: (v) => Validators.notEmpty(v, 'Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Masuk',
              loading: _loading,
              onPressed: busy ? null : _submit,
            ),
            if (_biometricReady) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy ? null : _biometricLogin,
                icon: _biometricBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.yellow,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded),
                label: const Text('Masuk dengan Biometrik'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: AppColors.yellow,
                  side: const BorderSide(color: AppColors.yellow),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Belum punya akun? ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: busy ? null : _openRegister,
                  child: const Text(
                    'Daftar Sekarang',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}