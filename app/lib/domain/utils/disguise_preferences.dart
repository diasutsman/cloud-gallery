import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data/services/firebase_service.dart';
import 'package:data/services/app_settings_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:data/domain/app_disguise_type.dart';
import 'package:data/log/logger.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'app_switcher.dart';
import 'package:data/services/app_settings_service.dart';

/// Manages disguise-related preferences like PIN codes and app settings
class DisguisePreferences {
  static const String _pinCodeKey = 'disguise_pin_code';

  // Default PIN code if not set
  static const String defaultPinCode = '1234';

  /// Retrieves the PIN code from SharedPreferences (PIN is kept local for security)
  static Future<String> getPinCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pinCodeKey) ?? defaultPinCode;
  }

  /// Saves the PIN code to SharedPreferences (PIN is kept local for security)
  static Future<bool> setPinCode(String pinCode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_pinCodeKey, pinCode);
  }

  /// Hashes a PIN using SHA-256
  static String hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Saves the hashed PIN to Firebase (via AppSettingsService)
  static Future<void> setPinHashFirebase(
    String pin,
    AppSettingsService service,
  ) async {
    final hash = hashPin(pin);
    await service.updatePinHash(hash);
  }

  /// Verifies the PIN by comparing its hash to the hash stored in Firebase
  static Future<bool> verifyPinWithFirebase(
    String pin,
    AppSettingsService service,
  ) async {
    final hash = hashPin(pin);
    final remoteHash = await service.getPinHash();
    return hash == remoteHash;
  }
}

/// Provider for the AppSettingsService
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return AppSettingsService(
    firebaseService,
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

/// Provider for the current PIN code
final disguisePinProvider = FutureProvider<String>((ref) async {
  return DisguisePreferences.getPinCode();
});

/// Provider for app settings
final appSettingsProvider = FutureProvider((ref) async {
  final settingsService = ref.watch(appSettingsServiceProvider);
  try {
    return await settingsService.getAppSettings();
  } catch (e) {
    // If Firebase fetch fails, return null and fallback to local settings
    return null;
  }
});

/// Stream provider for app settings
final appSettingsStreamProvider = StreamProvider((ref) {
  final settingsService = ref.watch(appSettingsServiceProvider);
  return settingsService.streamAppSettings();
});

/// Provider for the current disguise type
final disguiseTypeProvider = StateProvider<AppDisguiseType>((ref) {
  final settings = ref.watch(appSettingsStreamProvider);
  return settings.when(
    data: (data) => data?.disguiseType != null
        ? data!.disguiseType.toAppDisguiseType()
        : AppDisguiseType.none,
    loading: () => AppDisguiseType.none,
    error: (_, __) => AppDisguiseType.none,
  );
});

/// Updates app disguise type in Firebase
Future<void> updateAppDisguiseType(
  AppDisguiseType type,
  AppSettingsService service,
) async {
  try {
    await service.updateDisguiseType(type.toDisguiseTypeString());
  } catch (e) {
    print('Error updating app disguise type: $e');
  }
}
