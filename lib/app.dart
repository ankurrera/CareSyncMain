import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/shared/presentation/widgets/splash_reveal_overlay.dart';
import 'features/shared/providers/theme_provider.dart';
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
  }

  @override
  void dispose() {
    AppLifecycleService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'CareSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final double screenWidth = mediaQueryData.size.width;
        final bool isWideScreen = screenWidth > 480;

        Widget appContent = child ?? const SizedBox();

        if (isWideScreen) {
          // Flat phone-width column — separation by colour, no shadow (elevation 0).
          appContent = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            MediaQuery(
              data: mediaQueryData.copyWith(
                // Prevent text size scaling from breaking standard layouts
                textScaler: TextScaler.noScaling,
                // Normalize layout boundaries on wide screens
                size:
                    isWideScreen
                        ? Size(480, mediaQueryData.size.height)
                        : mediaQueryData.size,
              ),
              child: Container(
                color:
                    isWideScreen
                        ? Theme.of(context).scaffoldBackgroundColor
                        : null,
                child: appContent,
              ),
            ),
            // Launch zoom-reveal splash; removes itself after animating.
            const SplashRevealOverlay(),
          ],
        );
      },
    );
  }
}
