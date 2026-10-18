import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/api_exception.dart';
import '../../services/user_service.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/menu_card.dart';
import 'biometric_settings_page.dart';

/// Profil: foto (kamera/galeri), nama (dapat diubah), role, dan keamanan.
/// [onUserChanged] memberi tahu kerangka utama agar sapaan di Beranda ikut berubah.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, this.onUserChanged});

  final UserModel user;
  final ValueChanged<UserModel>? onUserChanged;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _maxPhotoBytes = 1000000; // batas server 1 MB

  late UserModel _user;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _refresh();
  }

  void _apply(UserModel user) {
    setState(() {
      _user = user;
      _error = null;
    });
    widget.onUserChanged?.call(user);
  }

  /// Mengambil data terbaru, termasuk tautan foto (berlaku sementara).
  Future<void> _refresh() async {
    try {
      final me = await UserService.instance.getMe();
      if (mounted) _apply(me);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga.');
    }
  }

  Future<void> _choosePhotoSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeri'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickAndUpload(source);
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Diperkecil di perangkat (maks 512 px) agar unggahan ringan.
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null) return; // dibatalkan

      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        if (mounted)
          setState(
            () => _error = 'Ukuran foto terlalu besar. Pilih foto lain.',
          );
        return;
      }

      await UserService.instance.uploadAvatar(bytes);
      final me = await UserService.instance.getMe();
      if (mounted) _apply(me);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Tidak dapat membuka kamera/galeri. Periksa izin aplikasi.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editName() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _user.nama ?? _user.username),
    );
    if (name == null) return;
    if (name.length < 2) {
      setState(() => _error = 'Nama minimal 2 karakter.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await UserService.instance.updateName(name);
      if (mounted) _apply(me);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan tak terduga.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _roleLabel(String role) {
    switch (role) {
      case 'manager':
        return 'Manager';
      case 'staff':
        return 'Staff Gudang';
      default:
        return 'Customer';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_user.nama != null && _user.nama!.trim().isNotEmpty)
        ? _user.nama!.trim()
        : _user.username;

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
          Center(
            child: _Avatar(user: _user, busy: _busy, onTap: _choosePhotoSource),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Ubah nama',
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: _busy ? null : _editName,
              ),
            ],
          ),
          Text(
            '@${_user.username}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Center(child: _RoleChip(label: _roleLabel(_user.role))),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AuthErrorBox(message: _error!),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Muat ulang'),
              ),
            ),
          ],
          const SizedBox(height: 28),
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
                builder: (_) => BiometricSettingsPage(user: _user),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.busy, required this.onTap});

  final UserModel user;
  final bool busy;
  final VoidCallback onTap;

  Widget _initial() {
    final source = (user.nama != null && user.nama!.trim().isNotEmpty)
        ? user.nama!.trim()
        : user.username;
    return Center(
      child: Text(
        source.isEmpty ? '?' : source[0].toUpperCase(),
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = user.fotoUrl;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.yellow,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: url == null
                  ? _initial()
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initial(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.black,
                                ),
                              ),
                            ),
                    ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Material(
              color: AppColors.yellow,
              shape: const CircleBorder(
                side: BorderSide(color: AppColors.black, width: 3),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: busy ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : const Icon(
                          Icons.photo_camera_rounded,
                          size: 20,
                          color: AppColors.black,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.yellow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.black,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Dialog ubah nama. Memiliki controller sendiri agar dibuang pada waktu yang aman
/// (setelah animasi tutup selesai).
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Ubah Nama',
        style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Nama tampilan'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.white),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.yellow,
            foregroundColor: AppColors.black,
            elevation: 0,
            shape: const StadiumBorder(),
          ),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
