import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

final loggerProvider = Provider<Logger>(
  (ref) => Logger(
    filter: DevelopmentFilter(),
    printer: PrettyPrinter(
      methodCount: 8,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  ),
);

class UnitTestLoggerFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return false;
  }
}
