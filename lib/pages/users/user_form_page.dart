import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/staff_model.dart';
import '../../services/api_exception.dart';
import '../../services/staff_service.dart';
import '../../utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/password_field.dart';

/// Form akun staff. [staff] null = tambah akun baru; terisi = ubah akun tersebut.
/// Menutup dengan `true` jika ada perubahan tersimpan.
class UserFormPage extends StatefulWidget {
  const UserFormPage({super.key, this.staff});

  final StaffModel? staff;

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _nama = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.staff != null;

  @override
  void initState() {
    super.initState();
    final staff = widget.staff;
    if (staff != null) {
      _username.text = staff.username;
      _nama.text = staff.displayName;
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _nama.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateNama(String? value) {
    final text = (value ?? '').trim();
    if (text.length < 2 || text.length > 50) return 'Nama harus 2-50 karakter';
    return null;
  }

  String? _validatePassword(String? value) {
    // Saat mengubah akun, password boleh dikosongkan (tidak diganti).
    if (_isEdit && (value == null || value.isEmpty)) return null;
    return Validators.password(value);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staff = widget.staff;
      if (staff == null) {
        await StaffService.instance.create(
          username: _username.text.trim(),
          nama: _nama.text.trim(),
          password: _password.text,
        );
      } else {
        await StaffService.instance.update(
          staff.id,
          nama: _nama.text.trim(),
          password: _password.text.isEmpty ? null : _password.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Ubah Akun Staff' : 'Tambah Staff'),
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                AppTextField(
                  controller: _username,
                  label: 'Username',
                  hint: 'Contoh: gudang.satu',
                  icon: Icons.alternate_email_rounded,
                  autocorrect: false,
                  enabled: !_isEdit && !_loading, // username tidak dapat diubah
                  textInputAction: TextInputAction.next,
                  validator: _isEdit ? null : Validators.username,
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _nama,
                  label: 'Nama',
                  hint: 'Nama lengkap staff',
                  icon: Icons.person_outline_rounded,
                  enabled: !_loading,
                  textInputAction: TextInputAction.next,
                  validator: _validateNama,
                ),
                const SizedBox(height: 18),
                PasswordField(
                  controller: _password,
                  label: _isEdit ? 'Password baru (opsional)' : 'Password',
                  hint: _isEdit
                      ? 'Kosongkan jika tidak diganti'
                      : 'Minimal 6 karakter',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: _validatePassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isEdit
                ? 'Mengisi password baru akan mengeluarkan staff dari semua perangkat.'
                : 'Berikan password ini ke staff secara langsung. Staff belum dapat '
                      'menggantinya sendiri.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.3,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AuthErrorBox(message: _error!),
          ],
          const SizedBox(height: 24),
          AppButton(
            label: _isEdit ? 'Simpan Perubahan' : 'Buat Akun',
            loading: _loading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
