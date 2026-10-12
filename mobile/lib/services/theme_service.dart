import 'package:flutter/material.dart';

import 'sync_metadata_service.dart';

class ThemeService {
  static final ThemeService instance = ThemeService._internal();

  ThemeService._internal();

  static const String _metadataKey = 'app_theme_mode';

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  ThemeMode get currentThemeMode => themeModeNotifier.value;

  /// Loads saved theme mode from persistent metadata.
  Future<void> init() async {
    try {
      final savedValue = await SyncMetadataService.instance.get(_metadataKey);
      if (savedValue != null) {
        switch (savedValue.trim().toLowerCase()) {
          case 'light':
            themeModeNotifier.value = ThemeMode.light;
            break;
          case 'dark':
            themeModeNotifier.value = ThemeMode.dark;
            break;
          case 'system':
            themeModeNotifier.value = ThemeMode.system;
            break;
          default:
            themeModeNotifier.value = ThemeMode.dark;
        }
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.dark;
    }
  }

  /// Sets and persists the selected theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      await SyncMetadataService.instance.set(_metadataKey, mode.name);
    } catch (_) {}
  }

  /// Returns Marathi display label for given ThemeMode.
  static String getLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'गड रात्री (Dark Mode)';
      case ThemeMode.light:
        return 'दिवस (Light Mode)';
      case ThemeMode.system:
        return 'फोन सिस्टीमप्रमाणे (System Default)';
    }
  }

  /// Returns icon for given ThemeMode.
  static IconData getIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}
