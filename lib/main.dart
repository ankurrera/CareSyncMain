import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env_config.dart';
import 'core/error/app_error_handler.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize global framework and platform error handling
      AppErrorHandler.initialize();

      // Use bundled/cached fonts only — never fetch at runtime (offline-safe;
      // a failed fetch otherwise throws). DM Sans / DM Mono are bundled assets.
      GoogleFonts.config.allowRuntimeFetching = false;

      // Load environment variables if available
      try {
        await dotenv.load(fileName: '.env');
      } catch (_) {
        // Suppress error if .env asset is missing (uses compile-time or default fallbacks)
      }

      // Lock orientation to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Initialize Supabase
      await Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        publishableKey: EnvConfig.supabaseAnonKey,
      );

      runApp(
        const ProviderScope(
          observers: [AppProviderObserver()],
          child: CareSync(),
        ),
      );
    },
    (error, stack) {
      AppErrorHandler.handleError(error, stack, context: 'runZonedGuarded');
    },
  );
}
