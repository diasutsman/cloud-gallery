import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data/models/app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:data/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Provider for the AppSettingsService
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return AppSettingsService(
    firebaseService,
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

/// Service to manage application settings stored in Firebase
class AppSettingsService {
  final FirebaseService _firebaseService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const String _collectionPath = 'app_settings';
  
  AppSettingsService(
    this._firebaseService,
    this._firestore,
    this._auth,
  );
  
  /// Get the Firestore collection reference for app settings
  CollectionReference get _collection => 
      _firestore.collection(_collectionPath);
  
  /// Get the current userId from Firebase Authentication
  String? get _userId => _auth.currentUser?.uid;

  /// Get app settings for the current user
  Future<AppSettings> getAppSettings() async {
    if (_userId == null || !_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    try {
      final docSnapshot = await _collection.doc(_userId).get();
      
      if (docSnapshot.exists) {
        return AppSettings.fromDocument(docSnapshot);
      } else {
        // Create default settings if they don't exist
        final defaultSettings = AppSettings.initial(_userId!);
        await _saveAppSettings(defaultSettings);
        return defaultSettings;
      }
    } catch (e) {
      throw Exception('Failed to fetch app settings: $e');
    }
  }
  
  /// Save app settings to Firebase
  Future<void> _saveAppSettings(AppSettings settings) async {
    if (_userId == null || !_firebaseService.isAuthenticated) {
      throw Exception('User not authenticated');
    }
    
    try {
      await _collection.doc(_userId).set(settings.toMap());
    } catch (e) {
      throw Exception('Failed to save app settings: $e');
    }
  }
  
  /// Update app disguise type and save to Firebase
  Future<AppSettings> updateDisguiseType(String disguiseType) async {
    final currentSettings = await getAppSettings();
    final updatedSettings = currentSettings.copyWith(
      disguiseType: disguiseType,
      updatedAt: DateTime.now().toIso8601String(),
    );
    
    await _saveAppSettings(updatedSettings);
    return updatedSettings;
  }
  
  /// Update custom app name and save to Firebase
  Future<AppSettings> updateCustomAppName(String customAppName) async {
    final currentSettings = await getAppSettings();
    final updatedSettings = currentSettings.copyWith(
      customAppName: customAppName,
      updatedAt: DateTime.now().toIso8601String(),
    );
    
    await _saveAppSettings(updatedSettings);
    return updatedSettings;
  }
  
  /// Update authentication requirement and save to Firebase
  Future<AppSettings> updateAuthRequirement(bool isAuthRequired) async {
    final currentSettings = await getAppSettings();
    final updatedSettings = currentSettings.copyWith(
      isAuthRequired: isAuthRequired,
      updatedAt: DateTime.now().toIso8601String(),
    );
    
    await _saveAppSettings(updatedSettings);
    return updatedSettings;
  }
  
  /// Update dark mode setting and save to Firebase
  Future<AppSettings> updateDarkMode(bool isDarkModeEnabled) async {
    final currentSettings = await getAppSettings();
    final updatedSettings = currentSettings.copyWith(
      isDarkModeEnabled: isDarkModeEnabled,
      updatedAt: DateTime.now().toIso8601String(),
    );
    
    await _saveAppSettings(updatedSettings);
    return updatedSettings;
  }
  
  /// Stream app settings changes
  Stream<AppSettings?> streamAppSettings() {
    if (_userId == null || !_firebaseService.isAuthenticated) {
      return Stream.value(null);
    }
    
    return _collection.doc(_userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return AppSettings.fromDocument(snapshot);
      } else {
        return null;
      }
    });
  }
}
