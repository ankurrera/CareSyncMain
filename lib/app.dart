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
      builder: (context, child) {
        final mediaQueryData = MediaQuery.of(context);
        final double screenWidth = mediaQueryData.size.width;
        final bool isWideScreen = screenWidth > 480;

        Widget appContent = child ?? const SizedBox();

        if (isWideScreen) {
          appContent = Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          );
        }

        return MediaQuery(
          data: mediaQueryData.copyWith(
            // Prevent text size scaling from breaking standard layouts
            textScaler: TextScaler.noScaling,
            // Normalize layout boundaries on wide screens
            size: isWideScreen
                ? Size(480, mediaQueryData.size.height)
                : mediaQueryData.size,
          ),
          child: Container(
            color: isWideScreen ? const Color(0xFFF8FAFC) : null,
            child: appContent,
          ),
        );
      },
    );
  }
}