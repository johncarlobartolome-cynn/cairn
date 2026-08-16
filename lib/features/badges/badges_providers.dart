import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'badge_board.dart';

/// Everything the badges screen draws, as one answer.
///
/// The library and the unlocked rows arrive on two Drift streams, and half an
/// answer is a wrong screen rather than an unfinished one: a board built from
/// the peaks alone draws every badge locked, so a frame could say the climber
/// has earned nothing. The peaks list already carries that rule after T16, and
/// this is the same rule in the same shape. Both, or the spinner.
///
/// A plain [Provider] over the two, not a third stream: nothing here queries,
/// it only reconciles what the two [StreamProvider]s already have. Riverpod
/// recomputes it when either moves, and a write anywhere refreshes the screen
/// with nothing to invalidate by hand.
final badgeBoardProvider = Provider<AsyncValue<BadgeBoard>>((ref) {
  final AsyncValue<List<Mountain>> library = ref.watch(mountainsProvider);
  final AsyncValue<List<Achievement>> unlocked = ref.watch(
    achievementsProvider,
  );

  for (final AsyncValue<Object> read in <AsyncValue<Object>>[
    library,
    unlocked,
  ]) {
    final Object? failure = read.error;
    if (failure != null) {
      return AsyncValue<BadgeBoard>.error(
        failure,
        read.stackTrace ?? StackTrace.empty,
      );
    }
  }

  if (!library.hasValue || !unlocked.hasValue) {
    return const AsyncValue<BadgeBoard>.loading();
  }

  return AsyncValue<BadgeBoard>.data(
    BadgeBoard.from(
      library: library.requireValue,
      unlocked: unlocked.requireValue,
    ),
  );
});
