import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_scaffold.dart';

/// Mengaktifkan/mematikan login biometrik di PERANGKAT INI.
/// Pengaturan ini tidak disimpan di server karena sifatnya per-perangkat.
class BiometricSettingsPage extends StatefulWidget {
  const BiometricSettingsPage({super.key, required this.user});

  final UserModel user;

  @override
  State<BiometricSettingsPage> createState() => _BiometricSettingsPageState();
}

class _BiometricSettingsPageState extends State<BiometricSettingsPage> {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await AuthService.instance.isBiometricEnabledFor(widget.user);
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      if (value) {
        final result = await AuthService.instance.enableBiometric(widget.user);
        if (!mounted) return;
        switch (result) {
          case BiometricEnableResult.enabled:
            setState(() => _enabled = true);
          case BiometricEnableResult.unavailable:
            setState(() => _message =
                'Perangkat belum mendukung biometrik, atau belum ada sidik jari/wajah '
                'yang terdaftar. Daftarkan dulu di Pengaturan HP.');
          case BiometricEnableResult.cancelled:
            setState(() => _message =
                'Verifikasi dibatalkan. Login biometrik belum diaktifkan.');
        }
      } else {
        await AuthService.instance.disableBiometric();
        if (!mounted) return;
        setState(() => _enabled = false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Biometrik'),
        backgroundColor: AppColors.black,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.yellow))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SwitchListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: const Text(
                      'Masuk dengan biometrik',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Gunakan sidik jari atau wajah untuk membuka Noir.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    value: _enabled,
                    onChanged: _busy ? null : _toggle,
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(message: _message!),
                ],
                const SizedBox(height: 24),
                const _Note('Saat aktif, Noir meminta sidik jari/wajah setiap kali dibuka.'),
                const _Note('Berlaku hanya di perangkat ini, dan mati otomatis saat Anda logout.'),
                const _Note('Password tetap bisa dipakai kapan saja sebagai cadangan.'),
              ],
            ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}