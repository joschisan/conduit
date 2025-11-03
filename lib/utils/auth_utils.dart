import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Requires biometric authentication if available.
/// Throws an exception if authentication fails or is cancelled by the user.
/// If no biometrics are available, the action is allowed to proceed.
Future<void> requireBiometricAuth(BuildContext context) async {
  final auth = LocalAuthentication();

  // If no biometrics available, allow the action
  if (!(await auth.canCheckBiometrics || await auth.isDeviceSupported())) {
    return;
  }

  // Biometrics available, require authentication
  final didAuthenticate = await auth.authenticate(
    localizedReason: 'Please authenticate to continue',
    options: const AuthenticationOptions(
      stickyAuth: false,
      biometricOnly: false,
    ),
  );

  if (!didAuthenticate) {
    throw 'Authentication required';
  }
}
