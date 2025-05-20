import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/app_disguise_type.dart';

/// Model class for app settings stored in Firebase
class AppSettings {
  final String? customAppName;
  final String disguiseType;
  final bool isAuthRequired;
  final bool isDarkModeEnabled;
  final String updatedAt;
  final String userId;
  final String pinHash;

  AppSettings({
    this.customAppName = "Photo & Video Vault",
    required this.disguiseType,
    required this.isAuthRequired,
    required this.isDarkModeEnabled,
    required this.updatedAt,
    required this.userId,
    this.pinHash = '',
  });

  factory AppSettings.initial(String userId) {
    return AppSettings(
      customAppName: "Photo & Video Vault",
      disguiseType: "none",
      isAuthRequired: true,
      isDarkModeEnabled: false,
      updatedAt: DateTime.now().toIso8601String(),
      userId: userId,
      pinHash: '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customAppName': customAppName,
      'disguiseType': disguiseType,
      'isAuthRequired': isAuthRequired,
      'isDarkModeEnabled': isDarkModeEnabled,
      'updatedAt': updatedAt,
      'userId': userId,
      'pinHash': pinHash,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      customAppName: map['customAppName'] ?? "Photo & Video Vault",
      disguiseType: map['disguiseType'] ?? "none",
      isAuthRequired: map['isAuthRequired'] ?? true,
      isDarkModeEnabled: map['isDarkModeEnabled'] ?? false,
      updatedAt: map['updatedAt'] ?? DateTime.now().toIso8601String(),
      userId: map['userId'] ?? '',
      pinHash: map['pinHash'] ?? '',
    );
  }

  factory AppSettings.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      return AppSettings.initial(doc.id);
    }
    return AppSettings.fromMap({...data, 'userId': doc.id});
  }

  AppSettings copyWith({
    String? customAppName,
    String? disguiseType,
    bool? isAuthRequired,
    bool? isDarkModeEnabled,
    String? updatedAt,
    String? userId,
    String? pinHash,
  }) {
    return AppSettings(
      customAppName: customAppName ?? this.customAppName,
      disguiseType: disguiseType ?? this.disguiseType,
      isAuthRequired: isAuthRequired ?? this.isAuthRequired,
      isDarkModeEnabled: isDarkModeEnabled ?? this.isDarkModeEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      pinHash: pinHash ?? this.pinHash,
    );
  }
}

// Helper extension to convert between AppSettings and AppDisguiseType
extension AppDisguiseTypeExtension on String {
  AppDisguiseType toAppDisguiseType() {
    switch (this) {
      case 'calculator':
        return AppDisguiseType.calculator;
      case 'calendar':
        return AppDisguiseType.calendar;
      case 'notes':
        return AppDisguiseType.notes;
      case 'clock':
        return AppDisguiseType.clock;
      case 'weather':
        return AppDisguiseType.weather;
      default:
        return AppDisguiseType.none;
    }
  }
}

extension AppDisguiseTypeStringExtension on AppDisguiseType {
  String toDisguiseTypeString() {
    switch (this) {
      case AppDisguiseType.calculator:
        return 'calculator';
      case AppDisguiseType.calendar:
        return 'calendar';
      case AppDisguiseType.notes:
        return 'notes';
      case AppDisguiseType.clock:
        return 'clock';
      case AppDisguiseType.weather:
        return 'weather';
      case AppDisguiseType.none:
        return 'none';
    }
  }
}
