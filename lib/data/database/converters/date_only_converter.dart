import 'package:drift/drift.dart';

/// Stores a [DateTime] as the calendar day it names, as `YYYY-MM-DD` text.
///
/// A hike happens on a day, not at an instant. Drift's default storage writes
/// Unix epoch seconds, which makes the value depend on the phone's timezone: a
/// climb logged as 11 August in Manila reads back as 10 August once the device
/// moves far enough west. Everything below the day is dropped on the way in, so
/// there is nothing left to shift.
///
/// The converter is the enforcement point rather than a convention. Call sites
/// hand over whatever [DateTime] they happen to hold, and the rule holds without
/// any of them knowing it exists.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  String toSql(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Returns UTC midnight, so `.year`, `.month` and `.day` read back the stored
  /// day in every zone. A local [DateTime] here would reintroduce the shift the
  /// converter exists to remove.
  @override
  DateTime fromSql(String fromDb) {
    final parts = fromDb.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
