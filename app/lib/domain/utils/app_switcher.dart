import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  
  // Key for storing disguise type in shared preferences
  static const String _disguiseTypeKey = 'app_disguise_type';

  /// Switches the app's launcher icon and name based on the selected disguise type
  static Future<void> switchAppLauncher(AppDisguiseType disguiseType) async {
    try {
      // Store the selected disguise type in shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_disguiseTypeKey, disguiseType.index);
      
      final String aliasName = _getAliasNameFromDisguiseType(disguiseType);
      await platform.invokeMethod('setLauncherAlias', {'alias': aliasName});
    } on PlatformException catch (e) {
      print("Failed to switch launcher: ${e.message}");
    }
  }
  
  /// Get the current app disguise type from shared preferences
  static Future<AppDisguiseType> getCurrentDisguiseType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final int index = prefs.getInt(_disguiseTypeKey) ?? 0; // Default to 'none'
      return AppDisguiseType.values[index];
    } catch (e) {
      print("Failed to get current disguise type: $e");
      return AppDisguiseType.none; // Default to 'none' in case of errors
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
