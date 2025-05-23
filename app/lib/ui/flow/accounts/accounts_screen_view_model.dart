import 'dart:async';
import 'dart:io';
import 'package:data/handlers/notification_handler.dart';
import 'package:data/log/logger.dart';
import 'package:data/models/media_process/media_process.dart';
import 'package:data/repositories/media_process_repository.dart';
import 'package:data/storage/provider/preferences_provider.dart';

import '../../../domain/utils/app_switcher.dart';
import 'package:data/domain/app_disguise_type.dart';
import 'package:data/services/auth_service.dart';
import 'package:data/services/device_service.dart';
import 'package:data/storage/app_preferences.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/utils/app_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'accounts_screen_view_model.freezed.dart';

final accountsStateNotifierProvider =
    StateNotifierProvider.autoDispose<AccountsStateNotifier, AccountsState>(
  (ref) => AccountsStateNotifier(
    ref.read(deviceServiceProvider),
    ref.read(authServiceProvider),
    ref.read(AppPreferences.dropboxAutoBackUp.notifier),
    ref.read(AppPreferences.googleDriveAutoBackUp.notifier),
    ref.read(mediaProcessRepoProvider),
    ref.read(notificationHandlerProvider),
    ref.read(loggerProvider),
  ),
);

class AccountsStateNotifier extends StateNotifier<AccountsState> {
  final DeviceService _deviceService;
  final AuthService _authService;
  final PreferenceNotifier<bool?> _autoBackupInGoogleDriveController;
  final PreferenceNotifier<bool?> _autoBackupInDropboxController;
  final MediaProcessRepo _mediaProcessRepo;
  final NotificationHandler _notificationHandler;
  final Logger _logger;
  StreamSubscription? _googleAccountSubscription;

  AccountsStateNotifier(
    this._deviceService,
    this._authService,
    this._autoBackupInDropboxController,
    this._autoBackupInGoogleDriveController,
    this._mediaProcessRepo,
    this._notificationHandler,
    this._logger,
  ) : super(AccountsState(googleAccount: _authService.googleAccount)) {
    _loadAppDisguiseType();
    init();
    updateNotificationsPermissionStatus();
  }

  Future<void> init() async {
    _getAppVersion();
    _googleAccountSubscription =
        _authService.onGoogleAccountChange.listen((event) {
      updateUser(event);
    });
  }

  /// Loads the current app disguise type from SharedPreferences
  Future<void> _loadAppDisguiseType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final disguiseTypeIndex = prefs.getInt('app_disguise_type') ?? 0;
      final disguiseType = AppDisguiseType.values[disguiseTypeIndex];
      state = state.copyWith(appDisguiseType: disguiseType);
    } catch (e) {
      _logger.e('Error loading app disguise type: $e');
    }
  }

  /// Sets the app disguise type and updates the app icon/name
  Future<void> setAppDisguiseType(AppDisguiseType disguiseType) async {
    try {
      state = state.copyWith(error: null);

      // Save the setting to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('app_disguise_type', disguiseType.index);

      // Update the app icon and name using AppSwitcher
      await AppSwitcher.switchAppLauncher(disguiseType);

      // Update the state
      state = state.copyWith(appDisguiseType: disguiseType);
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to set app disguise type",
        error: e,
        stackTrace: s,
      );
    }
  }

  @override
  void dispose() {
    _googleAccountSubscription?.cancel();
    super.dispose();
  }

  Future<void> updateNotificationsPermissionStatus({
    bool openSettingsIfPermanentlyDenied = false,
  }) async {
    try {
      state = state.copyWith(error: null);
      bool isNotificationEnabled =
          await _notificationHandler.checkPermissionIsEnabled() ?? false;
      if (!isNotificationEnabled && openSettingsIfPermanentlyDenied) {
        await openAppSettings();
        isNotificationEnabled =
            await _notificationHandler.checkPermissionIsEnabled() ?? false;
      }
      state =
          state.copyWith(notificationsPermissionStatus: isNotificationEnabled);
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to request permission",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> clearCache() async {
    try {
      state = state.copyWith(clearCacheLoading: true, error: null);
      final cacheDirectory = await getApplicationCacheDirectory();
      if (await cacheDirectory.exists()) {
        final files = cacheDirectory.listSync().where(
              (file) =>
                  file is File &&
                  (file.path.contains('thumbnail_') ||
                      file.path.contains('network_image_')),
            );
        for (var file in files) {
          await file.delete();
        }
      }
      state = state.copyWith(clearCacheLoading: false);
    } catch (e, s) {
      state = state.copyWith(error: e, clearCacheLoading: false);
      _logger.e(
        "AccountsStateNotifier: unable to clear cache",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> rateUs() async {
    try {
      state = state.copyWith(error: null);
      await _deviceService.rateApp();
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to rate app",
        error: e,
        stackTrace: s,
      );
    }
  }

  void updateUser(GoogleSignInAccount? account) {
    state = state.copyWith(googleAccount: account);
  }

  Future<void> signInWithGoogle() async {
    try {
      state = state.copyWith(error: null);
      await _authService.signInWithGoogle();
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to sign in with google",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> signOutWithGoogle() async {
    try {
      state = state.copyWith(error: null);
      _mediaProcessRepo
          .removeAllWaitingUploadsOfProvider(MediaProvider.googleDrive);
      await _authService.signOutWithGoogle();
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to sign out with google",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> signInWithDropbox() async {
    try {
      state = state.copyWith(error: null);
      await _authService.signInWithDropBox();
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to sign in with dropbox",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> signOutWithDropbox() async {
    try {
      state = state.copyWith(error: null);
      _mediaProcessRepo
          .removeAllWaitingUploadsOfProvider(MediaProvider.dropbox);
      await _authService.signOutWithDropBox();
    } catch (e, s) {
      state = state.copyWith(error: e);
      _logger.e(
        "AccountsStateNotifier: unable to sign out with dropbox",
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> toggleAutoBackupInGoogleDrive(bool value) async {
    _autoBackupInGoogleDriveController.state = value;

    if (value) {
      _mediaProcessRepo.autoBackupInGoogleDrive();
    } else {
      _mediaProcessRepo.stopAutoBackup(MediaProvider.googleDrive);
    }
  }

  Future<void> toggleAutoBackupInDropbox(bool value) async {
    _autoBackupInDropboxController.state = value;

    if (value) {
      _mediaProcessRepo.autoBackupInDropbox();
    } else {
      _mediaProcessRepo.stopAutoBackup(MediaProvider.dropbox);
    }
  }

  Future<void> _getAppVersion() async {
    final version = await _deviceService.version;
    state = state.copyWith(version: version);
  }
}

@freezed
class AccountsState with _$AccountsState {
  const factory AccountsState({
    @Default(true) bool notificationsPermissionStatus,
    @Default(false) bool clearCacheLoading,
    String? version,
    Object? error,
    GoogleSignInAccount? googleAccount,
    @Default(AppDisguiseType.none) AppDisguiseType appDisguiseType,
  }) = _AccountsState;
}
