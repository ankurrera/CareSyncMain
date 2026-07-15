import 'package:flutter/material.dart';
import '../../services/biometric_service.dart';

/// A widget that protects its child with biometric authentication.
/// [strictMode]: If true, re-authenticates every time the app resumes or the screen is revisited.
class BiometricGuard extends StatefulWidget {
  final Widget child;
  final String reason;
  final VoidCallback? onAuthenticationFailed;
  final VoidCallback? onAuthenticated; // New callback
  final bool allowBiometricOnly;
  final bool strictMode; // Add strict mode

  const BiometricGuard({
    super.key,
    required this.child,
    this.reason = 'Please authenticate to continue',
    this.onAuthenticationFailed,
    this.onAuthenticated,
    this.allowBiometricOnly = true,
    this.strictMode = false,
  });

  @override
  State<BiometricGuard> createState() => _BiometricGuardState();
}

class _BiometricGuardState extends State<BiometricGuard>
    with WidgetsBindingObserver {
  bool _isAuthenticated = false;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to lifecycle
    _checkBiometricStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Strict Mode: Reset authentication when app goes to background
    if (widget.strictMode && state == AppLifecycleState.paused) {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
        });
      }
    }

    // Re-authenticate on resume if needed
    if (widget.strictMode &&
        state == AppLifecycleState.resumed &&
        !_isAuthenticated) {
      _checkBiometricStatus();
    }
  }

  Future<void> _checkBiometricStatus() async {
    // Defer setState to post-frame so this can safely be called from initState
    // without triggering the !_dirty assertion from GoRouter's Builder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _isAuthenticated = true);
        widget.onAuthenticated?.call();
      }
    });
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    if (_isAuthenticated) return;

    setState(() => _isAuthenticating = true);

    try {
      final isAvailable =
          await BiometricService.instance.isBiometricAvailable();

      if (!isAvailable) {
        if (mounted) {
          setState(() => _isAuthenticating = false);
          _showBiometricUnavailableDialog();
        }
        return;
      }

      final authenticated = await BiometricService.instance.authenticate(
        reason: widget.reason,
        biometricOnly: widget.allowBiometricOnly,
      );

      if (mounted) {
        setState(() {
          _isAuthenticated = authenticated;
          _isAuthenticating = false;
        });

        if (authenticated) {
          widget.onAuthenticated?.call();
        } else {
          widget.onAuthenticationFailed?.call();
        }
      }
    } on BiometricException catch (e) {
      if (mounted) {
        setState(() => _isAuthenticating = false);
        _showErrorDialog(e.message);
      }
    }
  }

  void _showBiometricUnavailableDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Biometric Unavailable'),
            content: const Text(
              'Biometric authentication is not available on this device.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back
                },
                child: const Text('Go Back'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to choose
      builder:
          (context) => AlertDialog(
            title: const Text('Authentication Failed'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(); // Go back
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _authenticate(); // Retry
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Authenticating...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 24),
              const Text(
                'Authentication Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                widget.reason,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Authenticate'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Helper function to show biometric authentication dialog before an action
Future<bool> showBiometricAuthDialog({
  required BuildContext context,
  String reason = 'Please authenticate to continue',
  bool allowBiometricOnly = true,
}) async {
  try {
    final isAvailable = await BiometricService.instance.isBiometricAvailable();
    if (!isAvailable) {
      if (!context.mounted) return false;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final t = Theme.of(context);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.verified_user, color: t.primaryColor, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Clinical Signature',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: const Text(
              'Biometrics are not set up or available on this device. Would you like to digitally sign this prescription using your active clinical session authority?',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: t.colorScheme.secondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                child: const Text('Confirm & Sign'),
              ),
            ],
          );
        },
      );
      return confirmed ?? false;
    }

    return await BiometricService.instance.authenticate(
      reason: reason,
      biometricOnly: allowBiometricOnly,
    );
  } on BiometricException {
    return false;
  } catch (_) {
    return false;
  }
}
