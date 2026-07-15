import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logging/app_logger.dart';

/// Centralized global error handler for CareSync.
///
/// Hooks into Flutter framework errors, platform-level unhandled exceptions,
/// and Riverpod provider state changes.
abstract class AppErrorHandler {
  /// Initialize all system-wide error hooks.
  static void initialize() {
    // 1. Capture errors framework-side (during widget builds / layout)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      handleError(
        details.exception,
        details.stack ?? StackTrace.empty,
        context: 'FlutterFramework: ${details.context}',
      );
    };

    // 2. Capture platform/host-side asynchronous errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      handleError(error, stack, context: 'PlatformDispatcher');
      return true; // Tells the framework the error was handled.
    };
  }

  /// Process, categorize, and log any unhandled error.
  static void handleError(Object error, StackTrace stack, {String? context}) {
    final errStr = error.toString().toLowerCase();
    LogCategory category = LogCategory.general;

    // Detect category by examining typical error strings
    if (errStr.contains('supabase') ||
        errStr.contains('postgrest') ||
        errStr.contains('database') ||
        errStr.contains('postgres') ||
        errStr.contains('relation "') ||
        errStr.contains('column "')) {
      category = LogCategory.database;
    } else if (errStr.contains('socketexception') ||
        errStr.contains('failed host lookup') ||
        errStr.contains('http') ||
        errStr.contains('network') ||
        errStr.contains('connection')) {
      category = LogCategory.network;
    } else if (errStr.contains('auth') ||
        errStr.contains('jwt') ||
        errStr.contains('unauthorized') ||
        errStr.contains('signin') ||
        errStr.contains('signup') ||
        errStr.contains('login') ||
        errStr.contains('session')) {
      category = LogCategory.auth;
    } else if (errStr.contains('biometric') ||
        errStr.contains('face') ||
        errStr.contains('liveness') ||
        errStr.contains('embedding')) {
      category = LogCategory.biometric;
    } else if (errStr.contains('ocr') || errStr.contains('text_recognition')) {
      category = LogCategory.ocr;
    } else if (errStr.contains('kyc') || errStr.contains('verification')) {
      category = LogCategory.kyc;
    }

    final message =
        context != null
            ? '[$context] Unhandled exception occurred'
            : 'Unhandled exception occurred';

    AppLogger.error(
      message,
      category: category,
      error: error,
      stackTrace: stack,
    );
  }
}

/// Observer class to track Riverpod state changes and log failures.
class AppProviderObserver extends ProviderObserver {
  const AppProviderObserver();

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    AppLogger.error(
      'Provider failed to build / update: ${provider.name ?? provider.runtimeType}',
      category: LogCategory.general,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
