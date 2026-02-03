import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';
import 'services/app_lifecycle_service.dart';

class CareSync extends ConsumerStatefulWidget {
  const CareSync({super.key});

  @override
  ConsumerState<CareSync> createState() => _CareSyncState();
}

class _CareSyncState extends ConsumerState<CareSync> {
  @override
  void initState() {
    super.initState();
    AppLifecycleService.instance.initialize();
    // Check for biometric lock immediately on startup
    AppLifecycleService.instance.checkLockOnStartup();
  }

  @override
  void dispose() {
    AppLifecycleService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'CareSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Wrap the app to insert the Global Biometric Lock
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const _GlobalBiometricLock(),
          ],
        );
      },
    );
  }
}

/// Overlay widget that shows/hides based on stream events
class _GlobalBiometricLock extends StatefulWidget {
  const _GlobalBiometricLock();

  @override
  State<_GlobalBiometricLock> createState() => _GlobalBiometricLockState();
}

class _GlobalBiometricLockState extends State<_GlobalBiometricLock> {
  bool _isLocked = false;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = AppLifecycleService.instance.authStatusStream.listen((locked) {
      if (mounted) {
        setState(() => _isLocked = locked);
        if (locked) _triggerAuth();
      }
    });
  }

  Future<void> _triggerAuth() async {
    // Wait for UI to render
    await Future.delayed(const Duration(milliseconds: 200));
    await AppLifecycleService.instance.authenticate();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) return const SizedBox.shrink();

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'App Locked',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please authenticate to access CareSync',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 200,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => AppLifecycleService.instance.authenticate(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text(
                  'Unlock App',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}