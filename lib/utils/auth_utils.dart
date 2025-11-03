import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Returns true if:
/// - No biometrics are available (action can proceed), OR
/// - Biometrics are available AND user successfully authenticated
Future<bool> requireBiometricAuth(BuildContext context, String reason) async {
  final auth = LocalAuthentication();

  // If no biometrics available, allow the action
  if (!(await auth.canCheckBiometrics || await auth.isDeviceSupported())) {
    return true;
  }

  // Biometrics available, require authentication
  final didAuthenticate = await auth.authenticate(
    localizedReason: reason,
    options: const AuthenticationOptions(
      stickyAuth: false,
      biometricOnly: false,
    ),
  );

  return didAuthenticate;
}
