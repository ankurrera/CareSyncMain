import 'package:flutter/foundation.dart';

/// Log severity levels — determines what gets printed in each build mode.
enum LogLevel {
  verbose, // Trace-level detail — dev only
  debug, // Diagnostic information — dev only
  info, // Normal operational events — all builds
  warning, // Degraded state, recoverable — all builds
  error, // Operational failure — all builds
  critical, // Unrecoverable / security-relevant — all builds
}

/// Functional categories for log routing and filtering.
enum LogCategory {
  auth,
  biometric,
  database,
  network,
  navigation,
  lifecycle,
  ocr,
  emergency,
  encryption,
  kyc,
  general,
}

/// Centralized, production-safe logger for CareSync.
///
/// In **release** builds, [LogLevel.verbose] and [LogLevel.debug] messages are
/// completely suppressed — no output reaches logcat/console.
///
/// In **debug / profile** builds all levels are printed.
///
/// Usage:
/// ```dart
/// AppLogger.info('User signed in', category: LogCategory.auth);
/// AppLogger.error('Network timeout', category: LogCategory.network, error: e);
/// ```
abstract class AppLogger {
  // Minimum level to emit in release builds.
  static const LogLevel _releaseCutoff = LogLevel.info;

  // ── Public convenience API ────────────────────────────────────────────────

  static void verbose(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.verbose, category, message, error, stackTrace);

  static void debug(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.debug, category, message, error, stackTrace);

  static void info(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.info, category, message, error, stackTrace);

  static void warning(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.warning, category, message, error, stackTrace);

  static void error(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.error, category, message, error, stackTrace);

  static void critical(
    String message, {
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
  }) => _log(LogLevel.critical, category, message, error, stackTrace);

  // ── Internal implementation ───────────────────────────────────────────────

  static void _log(
    LogLevel level,
    LogCategory category,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // In release mode, suppress verbose and debug entirely.
    if (kReleaseMode && level.index < _releaseCutoff.index) {
      return;
    }

    final timestamp = DateTime.now().toIso8601String();
    final levelTag = _levelTag(level);
    final categoryTag = category.name.toUpperCase();

    final buffer = StringBuffer(
      '[$levelTag][$categoryTag][$timestamp] $message',
    );

    if (error != null) {
      buffer.write('\n  ↳ error: $error');
    }

    // Suppress stack traces in release builds.
    if (stackTrace != null && !kReleaseMode) {
      buffer.write('\n  ↳ stack: $stackTrace');
    }

    debugPrint(buffer.toString());
  }

  static String _levelTag(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'VRB';
      case LogLevel.debug:
        return 'DBG';
      case LogLevel.info:
        return 'INF';
      case LogLevel.warning:
        return 'WRN';
      case LogLevel.error:
        return 'ERR';
      case LogLevel.critical:
        return 'CRT';
    }
  }
}
