import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../routing/route_names.dart';
import '../../../../services/auth_controller.dart';
import '../../../auth/providers/auth_provider.dart';
import '../widgets/splash_reveal_overlay.dart';

/// Splash route. At launch the [SplashRevealOverlay] (mounted above the
/// router in [CareSync]) covers this screen with the identical visual; this
/// widget's job is session restore + picking the first destination, then
/// firing the overlay's zoom-reveal once that destination is beneath it.
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
    // Capture the reveal notifier BEFORE any awaits.
    // StateNotifier outlives this widget — safe to use even after unmount.
    final reveal = ref.read(splashRevealProvider.notifier);

    try {
      // Restore the session while the logo holds on screen; never reveal
      // before the minimum hold so the animation reads like the reference.
      // Hard 8s timeout prevents infinite hang on biometric prompt or slow network.
      final results = await Future.wait([
        AuthController.instance.restoreSession().timeout(
          const Duration(seconds: 8),
          onTimeout: () {
            AppLogger.warning(
              '[SPLASH] restoreSession timed out after 8s — falling back to login',
              category: LogCategory.lifecycle,
            );
            return SessionRestoreResult.loginRequired;
          },
        ),
        Future<void>.delayed(const Duration(milliseconds: 1500)),
      ]);

      // Widget may have been unmounted by the router redirect if the user is
      // already authenticated and all metadata resolved while we were awaiting.
      // In that case, the router already navigated to the correct screen — we
      // only need to trigger the overlay reveal and exit.
      if (!mounted) {
        AppLogger.info(
          '[SPLASH] Widget unmounted after restoreSession — router navigated first. Triggering reveal.',
          category: LogCategory.lifecycle,
        );
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => reveal.state = true,
        );
        return;
      }

      final result = results[0] as SessionRestoreResult;
      switch (result) {
        case SessionRestoreResult.success:
          await _navigateToDashboard(reveal);
          break;
        case SessionRestoreResult.biometricFailed:
        case SessionRestoreResult.loginRequired:
          _goAndReveal(RouteNames.roleSelection, reveal);
          break;
      }
    } catch (e, stackTrace) {
      AppLogger.error(
        '[SPLASH] Error during session restoration',
        category: LogCategory.lifecycle,
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        _goAndReveal(RouteNames.roleSelection, reveal);
      } else {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => reveal.state = true,
        );
      }
    }
  }

  Future<void> _navigateToDashboard(StateController<bool> reveal) async {
    // Wait up to 5 seconds for the profile provider to resolve.
    // The profile is a FutureProvider and may not have a value yet immediately
    // after session restore — reading it before it resolves always gives null,
    // causing every role to default to patientDashboard.
    String? role;
    try {
      final profile = await ref
          .read(currentProfileProvider.future)
          .timeout(const Duration(seconds: 5));
      role = profile?.role;
    } catch (e) {
      AppLogger.warning(
        '[SPLASH] Profile load timed out or failed — routing to patientDashboard',
        category: LogCategory.lifecycle,
      );
    }

    // Widget may have been unmounted while we waited for the profile.
    // The router has already navigated to the correct screen — just reveal.
    if (!mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reveal.state = true);
      return;
    }

    switch (role) {
      case 'doctor':
        _goAndReveal(RouteNames.doctorDashboard, reveal);
        break;
      case 'pharmacist':
        _goAndReveal(RouteNames.pharmacistDashboard, reveal);
        break;
      case 'patient':
      default:
        _goAndReveal(RouteNames.patientDashboard, reveal);
    }
  }

  /// Navigate, then start the zoom-reveal one frame later so the destination
  /// is already rendered beneath the overlay when it becomes transparent.
  void _goAndReveal(String location, StateController<bool> reveal) {
    context.go(location);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reveal.state = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Mirrors the overlay so mid-session redirects to '/' (e.g. while a
    // profile reloads) show the same static branding.
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset('assets/Splash_Screen.png', fit: BoxFit.cover),
      ),
    );
  }
}
