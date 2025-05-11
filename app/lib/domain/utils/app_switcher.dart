import 'package:flutter/services.dart';

/// Enum representing different app disguise types
enum AppDisguiseType {
  none,
  calculator,
  calendar,
  notes,
  weather,
  clock,
}

/// Utility class for switching app launcher icons and names
class AppSwitcher {
  static const platform = MethodChannel(
    'com.example.photo_and_video_vault_app/launcher',
  );

  /// Switches the app's launcher icon and name based on the selected disguise type
  static Future<void> switchAppLauncher(AppDisguiseType disguiseType) async {
    try {
      final String aliasName = _getAliasNameFromDisguiseType(disguiseType);
      await platform.invokeMethod('setLauncherAlias', {'alias': aliasName});
    } on PlatformException catch (e) {
      print("Failed to switch launcher: ${e.message}");
    }
  }

  /// Converts AppDisguiseType enum to the corresponding activity alias name
  static String _getAliasNameFromDisguiseType(AppDisguiseType disguiseType) {
    switch (disguiseType) {
      case AppDisguiseType.none:
        return "MainActivity"; // Default app icon
      case AppDisguiseType.calculator:
        return "MainActivityAliasCalculator";
      case AppDisguiseType.calendar:
        return "MainActivityAliasCalendar";
      case AppDisguiseType.notes:
        return "MainActivityAliasNotes";
      case AppDisguiseType.weather:
        return "MainActivityAliasWeather";
      case AppDisguiseType.clock:
        return "MainActivityAliasClock";
    }
  }
}
