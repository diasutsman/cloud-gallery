/// Enum representing different app disguise types
enum AppDisguiseType {
  none,
  calculator,
  calendar,
  notes,
  weather,
  clock,
}

/// Extension to convert string representation to AppDisguiseType
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

/// Extension to convert AppDisguiseType to string representation
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
