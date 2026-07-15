import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/secure_storage_service.dart';

/// Holds the active [ThemeMode], persisted via [SecureStorageService].
///
/// Loads the stored value asynchronously on first build (defaulting to
/// [ThemeMode.system] until it resolves). The Profile "Appearance" control
/// drives it via [ThemeModeNotifier.setMode].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final stored = await SecureStorageService.instance.getThemeMode();
    state = _fromString(stored);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await SecureStorageService.instance.setThemeMode(_toString(mode));
  }

  static ThemeMode _fromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
