import 'package:flutter/foundation.dart';

import '../../data/providers.dart';

/// Every badge the app has, earned or not, and the strings that name them.
///
/// The `achievements` table holds only what has been unlocked, so a row is
/// half the picture. The other half is the library: a peak with no badge row
/// against it is a badge still to earn, and it gets a tile saying so. Nothing
/// here reads a climb. A save is what unlocks, which is why two peaks climbed
/// on the emulator before T18 existed carry no badge and are drawn locked.

/// One badge, ready to draw.
///
/// [unlockedAt] carries the whole of the state: a day means earned, null means
/// still to earn. [condition] is written for the locked case and is present
/// either way, so nothing has to invent a sentence at the last moment.
@immutable
class BadgeView {
  const BadgeView({
    required this.name,
    required this.condition,
    required this.milestone,
    required this.unlockedAt,
  });

  /// What the badge is called. A peak badge is called after its peak.
  final String name;

  /// How to earn it, in one plain sentence.
  final String condition;

  /// Which milestone this is, or null for a peak badge.
  final AchievementType? milestone;

  /// The moment it fired, or null while it is locked.
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  bool get isMilestone => milestone != null;
}

/// The two groups the badges screen draws, already reconciled.
@immutable
class BadgeBoard {
  const BadgeBoard({required this.milestones, required this.peaks});

  /// In the order they are meant to be reached.
  final List<BadgeView> milestones;

  /// One per peak in the library, in the library's own order. Never a fixed
  /// six: a peak the user adds arrives here with a locked tile, which is the
  /// same rule that stops "all peaks" meaning six forever.
  final List<BadgeView> peaks;

  factory BadgeBoard.from({
    required List<Mountain> library,
    required List<Achievement> unlocked,
  }) {
    final milestoneDays = <AchievementType, DateTime>{};
    final peakDays = <int, DateTime>{};

    for (final badge in unlocked) {
      if (badge.type == AchievementType.perMountain) {
        final id = badge.mountainId;
        if (id != null) peakDays[id] = badge.unlockedAt;
      } else {
        milestoneDays[badge.type] = badge.unlockedAt;
      }
    }

    return BadgeBoard(
      milestones: <BadgeView>[
        for (final type in milestoneOrder)
          BadgeView(
            name: milestoneNames[type]!,
            condition: milestoneConditions[type]!,
            milestone: type,
            unlockedAt: milestoneDays[type],
          ),
      ],
      peaks: <BadgeView>[
        for (final peak in library)
          BadgeView(
            name: peak.name,
            condition: peakCondition,
            milestone: null,
            unlockedAt: peakDays[peak.id],
          ),
      ],
    );
  }

  List<BadgeView> get all => <BadgeView>[...milestones, ...peaks];

  int get total => milestones.length + peaks.length;

  int get earned => all.where((badge) => badge.isUnlocked).length;

  int get milestonesEarned =>
      milestones.where((badge) => badge.isUnlocked).length;
}

/// Every milestone, in the order they are meant to be reached.
///
/// Read off [AchievementType] rather than typed out, so a tier added there
/// reaches the screen instead of quietly going missing. `badge_board_test.dart`
/// holds the other half: every type in this list has a name and a condition
/// written for it, so a new tier fails a test rather than the app.
final List<AchievementType> milestoneOrder = AchievementType.values
    .where((type) => type != AchievementType.perMountain)
    .toList(growable: false);

/// Read these aloud before changing them. No em dashes, no parentheticals, no
/// slashes standing in for "or".
const Map<AchievementType, String> milestoneNames = <AchievementType, String>{
  AchievementType.firstClimb: 'First climb',
  AchievementType.threePeaks: 'Three peaks',
  // Not "All six". The library grows, and a badge that names a number is wrong
  // the moment somebody adds a peak of their own.
  AchievementType.allPeaks: 'All peaks',
};

/// What is left to do, in one sentence each.
///
/// This is the part of the screen that earns it. A locked badge with no
/// condition on it is a grey disc the reader has to guess at, and guessing is
/// worse than an empty screen.
const Map<AchievementType, String> milestoneConditions =
    <AchievementType, String>{
      AchievementType.firstClimb: 'Climb any peak.',
      AchievementType.threePeaks: 'Climb three different peaks.',
      AchievementType.allPeaks: 'Climb every peak in your library.',
    };

/// How a peak badge is earned.
///
/// The peak's name sits directly above it on the tile, so the sentence does not
/// say it twice.
const String peakCondition = 'Climb it.';
