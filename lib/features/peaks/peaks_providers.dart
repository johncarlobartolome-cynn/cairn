import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'peaks_board.dart';

/// Which pill is filled, and nothing else.
///
/// **Filter state is UI state.** It lives here for as long as the app is open
/// and is deliberately not written to the database or restored on launch. The
/// filter is a question the climber is asking right now, not a setting: coming
/// back a week later to a grid holding two of six peaks, because "Climbed" was
/// still selected, reads as lost data rather than as a remembered preference.
/// Every launch opens on the whole library, which is the screen's own answer to
/// "which of these have I climbed".
///
/// A [Notifier] rather than a `StateProvider`, per the architecture note: the
/// latter survives in Riverpod 2.6 and is gone in 3.x.
class PeakFilterNotifier extends Notifier<PeakFilter> {
  @override
  PeakFilter build() => PeakFilter.all;

  void select(PeakFilter filter) => state = filter;
}

final peakFilterProvider = NotifierProvider<PeakFilterNotifier, PeakFilter>(
  PeakFilterNotifier.new,
);

/// The whole peaks screen as one answer: the filtered list, the climbed ids,
/// and the two numbers under the greeting.
///
/// A plain [Provider] over the two streams and the filter, not a third stream:
/// nothing here queries, it only reconciles what is already in hand. Riverpod
/// recomputes it when any input moves, so a saved climb refreshes the grid and
/// the strip together with nothing to invalidate by hand.
///
/// **Both streams, or the spinner.** Half an answer is a wrong screen rather
/// than an unfinished one: a board built from the library alone draws every
/// peak unclimbed, and a frame of that says the climber has done nothing. T16
/// put that rule on this screen and this keeps it, now with the progress strip
/// behind the same gate. A strip reading "0 of 6" for one frame is the same lie
/// in a louder place.
final peaksBoardProvider = Provider<AsyncValue<PeaksBoard>>((ref) {
  final AsyncValue<List<Mountain>> library = ref.watch(mountainsProvider);
  final AsyncValue<Set<int>> climbed = ref.watch(climbedMountainIdsProvider);

  for (final AsyncValue<Object> read in <AsyncValue<Object>>[library, climbed]) {
    final Object? failure = read.error;
    if (failure != null) {
      return AsyncValue<PeaksBoard>.error(
        failure,
        read.stackTrace ?? StackTrace.empty,
      );
    }
  }

  if (!library.hasValue || !climbed.hasValue) {
    return const AsyncValue<PeaksBoard>.loading();
  }

  return AsyncValue<PeaksBoard>.data(
    PeaksBoard.from(
      library: library.requireValue,
      climbedIds: climbed.requireValue,
      filter: ref.watch(peakFilterProvider),
    ),
  );
});
