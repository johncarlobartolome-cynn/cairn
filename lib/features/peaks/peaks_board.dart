import 'package:flutter/foundation.dart';

import '../../data/providers.dart';

/// Everything the peaks list draws, as one answer: which peaks to show, which
/// of them are climbed, and how far up the library the climber is.
///
/// The library and the climbed ids arrive on two Drift streams and the filter
/// is a third input. Reconciling them in one place is what stops the grid, the
/// progress strip and the empty states ever disagreeing about the same set.

/// The three ways to read the list.
///
/// Declaration order is pill order, so the row of pills is built from
/// [PeakFilter.values] and a filter added here cannot go missing from the row.
enum PeakFilter {
  all('All'),
  toClimb('To climb'),
  climbed('Climbed');

  const PeakFilter(this.label);

  /// What the pill says. Read it aloud before changing it.
  final String label;

  /// Whether a peak in this state belongs on the list.
  bool admits({required bool isClimbed}) => switch (this) {
    PeakFilter.all => true,
    PeakFilter.toClimb => !isClimbed,
    PeakFilter.climbed => isClimbed,
  };
}

/// The list, already filtered, plus the two numbers the strip reads.
@immutable
class PeaksBoard {
  const PeaksBoard({
    required this.filter,
    required this.visible,
    required this.climbedIds,
    required this.libraryTotal,
    required this.climbedTotal,
  });

  /// Which pill is filled.
  final PeakFilter filter;

  /// The peaks this filter admits, in the library's own order.
  final List<Mountain> visible;

  /// Ids with at least one climb against them. The cards read this rather than
  /// a flag on the row, because a climb is what makes a peak climbed.
  final Set<int> climbedIds;

  /// Every peak in the library, whatever the filter says. Never a fixed six:
  /// the library is what the strip counts against, so a peak added later moves
  /// the total with no change here.
  final int libraryTotal;

  /// How many of [libraryTotal] have been climbed.
  final int climbedTotal;

  factory PeaksBoard.from({
    required List<Mountain> library,
    required Set<int> climbedIds,
    required PeakFilter filter,
  }) {
    bool isClimbed(Mountain peak) => climbedIds.contains(peak.id);

    return PeaksBoard(
      filter: filter,
      visible: <Mountain>[
        for (final peak in library)
          if (filter.admits(isClimbed: isClimbed(peak))) peak,
      ],
      climbedIds: climbedIds,
      libraryTotal: library.length,
      // Counted off the library rather than off the id set, so the strip can
      // never read "7 of 6" if a climb outlives the peak it was logged against.
      climbedTotal: library.where(isClimbed).length,
    );
  }

  bool get libraryIsEmpty => libraryTotal == 0;

  bool get isEmpty => visible.isEmpty;

  /// True once every peak in the library has been climbed. The good outcome,
  /// and the reason the "To climb" list can be empty on purpose.
  bool get allClimbed => !libraryIsEmpty && climbedTotal == libraryTotal;
}
