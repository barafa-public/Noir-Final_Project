import 'package:local_auth/local_auth.dart';

enum BiometricSupport {
  supported, // perangkat mendukung DAN sudah ada sidik jari/wajah terdaftar
  unavailable, // tidak ada perangkat keras, atau belum ada biometrik terdaftar
}

/// Pembungkus tipis untuk local_auth. Semua kegagalan (dibatalkan, terkunci,
/// tidak tersedia, error platform) dijadikan hasil "false"/"unavailable" agar
/// pemanggil cukup menawarkan fallback ke password.
class BiometricService {
  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  Future<BiometricSupport> checkSupport() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricSupport.unavailable;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricSupport.unavailable
          : BiometricSupport.supported;
    } catch (_) {
      return BiometricSupport.unavailable;
    }
  }

  /// true hanya jika pengguna berhasil memverifikasi.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
