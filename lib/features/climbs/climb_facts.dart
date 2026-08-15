import '../../data/providers.dart';

const List<String> _months = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// One calendar day spelled out, e.g. `11 August 2026`.
///
/// The day, month and year are read straight off [day]. Anything that converted
/// to local time first could move the date, which is the whole reason the column
/// stopped being a timestamp.
///
/// Serves a bare [DateTime] as well as [ClimbFacts.dayLabel], because the
/// mark-climbed sheet shows the chosen day before there is a row to read it off,
/// and the two have to say the same thing.
String climbDayLabel(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';

/// Display strings for one logged climb.
extension ClimbFacts on Climb {
  /// e.g. `11 August 2026`. The stored value is a calendar day held in UTC.
  String get dayLabel => climbDayLabel(date);
}
