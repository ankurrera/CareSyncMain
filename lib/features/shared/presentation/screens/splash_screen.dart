import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../routing/route_names.dart';
import '../../../../services/auth_controller.dart';
import '../../../auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Keep splash screen visible for 2 seconds to match design guidelines
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Use AuthController for session restoration
    final authController = AuthController.instance;
    final result = await authController.restoreSession();

    if (!mounted) return;

    switch (result) {
      case SessionRestoreResult.success:
        _navigateToDashboard();
        break;
      case SessionRestoreResult.biometricFailed:
        context.go(RouteNames.roleSelection);
        break;
      case SessionRestoreResult.loginRequired:
        context.go(RouteNames.roleSelection);
        break;
    }
  }

  void _navigateToDashboard() {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    switch (profile?.role) {
      case 'doctor':
        context.go(RouteNames.doctorDashboard);
        break;
      case 'pharmacist':
        context.go(RouteNames.pharmacistDashboard);
        break;
      case 'patient':
      default:
        context.go(RouteNames.patientDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/Splash_Screen.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
