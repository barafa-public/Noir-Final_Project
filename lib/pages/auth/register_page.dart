import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/password_field.dart';

/// Registrasi Customer. Role TIDAK dikirim dari aplikasi; server menetapkannya.
/// Berhasil -> kembali ke Login dengan membawa username (Navigator.pop).
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _alamat = TextEditingController();
  final _telepon = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _alamat.dispose();
    _telepon.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final username = _username.text.trim();
    try {
      await AuthService.instance.register(
        username: username,
        alamat: _alamat.text.trim(),
        telepon: _telepon.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(username);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted)
        setState(() => _error = 'Terjadi kesalahan tak terduga. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      logoWidth: 170,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buat Akun',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Daftar untuk mulai memesan',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            AppTextField(
              controller: _username,
              label: 'Username',
              hint: 'Pilih username',
              icon: Icons.person_outline_rounded,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              validator: Validators.username,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _alamat,
              label: 'Alamat',
              hint: 'Alamat lengkap pengiriman',
              icon: Icons.location_on_outlined,
              maxLines: 3,
              keyboardType: TextInputType.multiline,
              validator: (v) => Validators.notEmpty(v, 'Alamat'),
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _telepon,
              label: 'No. Telepon',
              hint: '08xxxxxxxxxx',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(20),
              ],
              validator: Validators.telepon,
            ),
            const SizedBox(height: 18),
            PasswordField(
              controller: _password,
              hint: 'Minimal 6 karakter',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: Validators.password,
            ),
            const SizedBox(height: 18),
            PasswordField(
              controller: _confirm,
              label: 'Konfirmasi Password',
              hint: 'Ulangi password',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => Validators.confirmPassword(v, _password.text),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              AuthErrorBox(message: _error!),
            ],
            const SizedBox(height: 24),
            AppButton(
              label: 'Daftar Sekarang',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Sudah punya akun? ',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text(
                    'Masuk',
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
