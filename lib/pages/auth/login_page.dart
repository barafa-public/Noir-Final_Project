import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
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
  const LoginPage({super.key, this.notice});

  final String? notice;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.notice;
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => MainShellPage(user: user)),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
            AppButton(label: 'Masuk', loading: _loading, onPressed: _submit),
            // TODO PBI-02.2: tombol "Masuk dengan biometrik" di sini (hanya jika
            // sudah diaktifkan di Profil dan perangkat mendukung).
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
                  onPressed: _loading ? null : _openRegister,
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
