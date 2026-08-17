import '../../data/providers.dart';
// The badges screen's own names for the milestones, read from there rather than
// written again here. The acknowledgement below has to call a badge exactly what
// the grid calls it, or the badge somebody goes looking for is not the one they
// were told they had earned.
import '../badges/badge_board.dart';

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

/// Said when a climb is saved and no badge fired, which is most saves.
const String climbSaved = 'Climb saved';

/// What the app says the moment a climb is saved.
///
/// **This is the app's payoff and it is one line long.** Marking a peak climbed
/// is what Cairn is for, and until T26 the whole event was these two words: the
/// card turned to colour on a screen nobody was looking at, and a first climb
/// unlocked two badges without mentioning either. So the badges are named here,
/// in the moment they are earned, on the only surface the person is already
/// looking at.
///
/// Named, and nothing more than named. No celebration, no takeover, no sound.
/// The rest of the app talks in short plain sentences and this is not the place
/// it starts shouting. A badge that was already in the file is not mentioned at
/// all, because a fourth trip up Batulao earns nothing and saying otherwise
/// would make the sentence worthless on the climb that does earn something.
///
/// Read the four shapes aloud. That is the whole test of this string:
///
/// * `Climb saved`
/// * `Climb saved. You earned the First climb badge.`
/// * `Climb saved. You earned two badges: Mt. Pulag and First climb.`
/// * `Climb saved. You earned three badges: Mt. Pulag, Three peaks and All
///   peaks.`
///
/// The count is a word rather than a digit, because a digit inside a spoken
/// sentence reads as a label. The peak's own badge comes first, since it is the
/// thing that was just done and the milestones are what it added up to.
String climbSavedMessage(EarnedBadges earned, {required String peakName}) {
  final List<String> badges = earnedBadgeNames(earned, peakName: peakName);

  return switch (badges.length) {
    0 => climbSaved,
    1 => '$climbSaved. You earned the ${badges.single} badge.',
    _ =>
      '$climbSaved. You earned ${_spokenCount(badges.length)} badges: '
          '${_spokenList(badges)}.',
  };
}

/// The badges a save earned, in the order the acknowledgement says them.
///
/// A peak badge is called after its peak, on the badges grid and here, so the
/// name comes from the peak the sheet was opened on. Nothing looks a mountain up
/// to say a sentence.
List<String> earnedBadgeNames(
  EarnedBadges earned, {
  required String peakName,
}) => <String>[
  if (earned.peak) peakName,
  for (final AchievementType type in earned.milestones) milestoneNames[type]!,
];

/// Counting words, for the few numbers this app ever says out loud.
///
/// One climb can earn three badges at the very most, so the list is short by
/// nature. It falls back to the digits rather than throwing, because a sentence
/// is not worth an exception.
const List<String> _counts = <String>[
  'no',
  'one',
  'two',
  'three',
  'four',
  'five',
];

String _spokenCount(int count) =>
    count < _counts.length ? _counts[count] : '$count';

/// `A and B`, or `A, B and C`. The way a person reads a list out.
String _spokenList(List<String> items) {
  if (items.length == 1) return items.single;
  final String last = items.last;
  final String rest = items.take(items.length - 1).join(', ');
  return '$rest and $last';
}
