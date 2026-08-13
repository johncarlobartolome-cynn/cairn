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

/// Display strings for one logged climb.
extension ClimbFacts on Climb {
  /// e.g. `11 August 2026`.
  ///
  /// The stored value is a calendar day held in UTC, so the day, month and year
  /// are read straight off it. Anything that converted to local time first could
  /// move the date, which is the whole reason the column stopped being a
  /// timestamp.
  String get dayLabel => '${date.day} ${_months[date.month - 1]} ${date.year}';
}
