import 'package:cairn/data/providers.dart';
import 'package:cairn/features/badges/badge_board.dart';
import 'package:cairn/features/climbs/climb_facts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The most emotionally loaded copy in the app, so it is written down rather
/// than assembled in a widget and eyeballed once.
///
/// Every expectation here is the whole sentence. A test that only checked a
/// badge name appeared would pass on a string nobody could read aloud, and
/// reading it aloud is the design's own test for a Cairn string.
void main() {
  EarnedBadges earned({
    bool peak = false,
    List<AchievementType> milestones = const <AchievementType>[],
  }) => EarnedBadges(peak: peak, milestones: milestones);

  String message(EarnedBadges badges, {String peakName = 'Mt. Pulag'}) =>
      climbSavedMessage(badges, peakName: peakName);

  test('a save that earned nothing keeps the two words it always had', () {
    expect(message(EarnedBadges.none), 'Climb saved');
    expect(climbSaved, 'Climb saved');
  });

  test('one badge is named in a sentence, not listed', () {
    expect(
      message(earned(peak: true)),
      'Climb saved. You earned the Mt. Pulag badge.',
    );
    expect(
      message(earned(milestones: <AchievementType>[AchievementType.allPeaks])),
      'Climb saved. You earned the All peaks badge.',
    );
  });

  test('a first climb names both of the badges it unlocks', () {
    // The case the ticket was written about: two badges fire and the app used
    // to mention neither.
    expect(
      message(
        earned(
          peak: true,
          milestones: <AchievementType>[AchievementType.firstClimb],
        ),
      ),
      'Climb saved. You earned two badges: Mt. Pulag and First climb.',
    );
  });

  test('three badges read as a spoken list', () {
    // Reachable: the third different peak on a three-peak library crosses the
    // halfway milestone and the last one in the same save.
    expect(
      message(
        earned(
          peak: true,
          milestones: <AchievementType>[
            AchievementType.threePeaks,
            AchievementType.allPeaks,
          ],
        ),
      ),
      'Climb saved. You earned three badges: Mt. Pulag, Three peaks and '
      'All peaks.',
    );
  });

  test('the peak badge is called after its peak, whatever the peak is', () {
    // A peak somebody added themselves, so the name is not one of the six.
    expect(
      message(earned(peak: true), peakName: 'Mt. Guiting-Guiting'),
      'Climb saved. You earned the Mt. Guiting-Guiting badge.',
    );
  });

  test('the milestone names are the ones the badges grid draws', () {
    // Read from one map rather than written twice. A badge named one thing in
    // the acknowledgement and another on the grid sends somebody looking for a
    // badge that is not there.
    for (final AchievementType type in milestoneOrder) {
      expect(
        message(earned(milestones: <AchievementType>[type])),
        contains(milestoneNames[type]!),
      );
    }
  });

  test('no string here carries an em dash, a slash or a parenthetical', () {
    final lines = <String>[
      climbSaved,
      message(earned(peak: true)),
      message(
        earned(
          peak: true,
          milestones: <AchievementType>[
            AchievementType.firstClimb,
            AchievementType.threePeaks,
          ],
        ),
      ),
    ];

    for (final String line in lines) {
      expect(line, isNot(contains('—')), reason: line);
      expect(line, isNot(contains('/')), reason: line);
      expect(line, isNot(contains('(')), reason: line);
    }
  });

  test('the counting words go up as far as a climb can earn', () {
    // Three is the ceiling today. The words carry on past it so a fourth badge
    // type would read as a sentence rather than as a digit dropped in the
    // middle of one.
    expect(
      message(
        earned(
          peak: true,
          milestones: <AchievementType>[
            AchievementType.firstClimb,
            AchievementType.threePeaks,
            AchievementType.allPeaks,
          ],
        ),
      ),
      startsWith('Climb saved. You earned four badges:'),
    );
  });
}
