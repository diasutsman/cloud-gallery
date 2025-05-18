import 'package:data/domain/app_disguise_type.dart';
import 'package:data/log/logger.dart';
import 'package:data/services/app_settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import 'app_switcher.dart';

/// Service for managing app disguise preferences with Firebase
class DisguisePreferencesService {
  final AppSettingsService _appSettingsService;
  final _log = Logger();

  DisguisePreferencesService(this._appSettingsService);

  /// Save the disguise type to Firebase and update app launcher
  Future<void> saveDisguiseType(AppDisguiseType disguiseType) async {
    try {
      // Update the app launcher (local change)
      await AppSwitcher.switchAppLauncher(disguiseType);

      // Save to Firebase
      await _appSettingsService
          .updateDisguiseType(disguiseType.toDisguiseTypeString());
      _log.d('Saved disguise type to Firebase: ${disguiseType.name}');
    } catch (e) {
      _log.e('Error saving disguise type: $e');
    }
  }
}

/// Provider for the DisguisePreferencesService
final disguisePreferencesServiceProvider =
    Provider<DisguisePreferencesService>((ref) {
  final appSettingsService = ref.watch(appSettingsServiceProvider);
  return DisguisePreferencesService(appSettingsService);
});
