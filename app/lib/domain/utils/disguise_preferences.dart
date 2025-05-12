import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_switcher.dart';

/// Manages disguise-related preferences like PIN codes
class DisguisePreferences {
  static const String _pinCodeKey = 'disguise_pin_code';

  // Default PIN code if not set
  static const String defaultPinCode = '1234';

  /// Retrieves the PIN code from SharedPreferences
  static Future<String> getPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinCodeKey) ?? defaultPinCode;
  }

  /// Saves the PIN code to SharedPreferences
  static Future<bool> setPinCode(String pinCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_pinCodeKey, pinCode);
  }
}

/// Provider for the current PIN code
final disguisePinProvider = FutureProvider<String>((ref) async {
  return DisguisePreferences.getPinCode();
});

/// Provider for the current disguise type
final disguiseTypeProvider = StateProvider<AppDisguiseType>((ref) {
  return AppDisguiseType.none;
});
