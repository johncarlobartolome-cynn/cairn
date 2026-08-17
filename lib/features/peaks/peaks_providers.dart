import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'peaks_board.dart';
import 'share_card.dart';

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

  for (final AsyncValue<Object> read in <AsyncValue<Object>>[
    library,
    climbed,
  ]) {
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

/// The card for one peak, or null while nobody has climbed it.
///
/// Two streams again, and the same rule as every other board in the app: both
/// answers, or neither. Half of this one is worse than half of a screen,
/// because the missing half is the tally, and a card that says "1 of 6" under a
/// peak that was actually the fifth is a wrong fact sent to somebody else.
///
/// It watches the whole library and the whole log rather than this peak's own
/// climbs, because the tally is a fact about the collection. That gives
/// `climbsProvider` its first consumer: T8 booked it as a provider nothing
/// read, to be used or deleted by E4.
///
/// Auto-disposed and per peak, like the other detail reads. Null is a real
/// answer, meaning there is nothing to share yet, and the peak detail screen
/// draws no share control when it gets one.
final shareCardProvider = Provider.autoDispose
    .family<AsyncValue<ShareCard?>, int>((ref, mountainId) {
      final AsyncValue<List<Mountain>> library = ref.watch(mountainsProvider);
      final AsyncValue<List<Climb>> log = ref.watch(climbsProvider);

      for (final AsyncValue<Object> read in <AsyncValue<Object>>[
        library,
        log,
      ]) {
        final Object? failure = read.error;
        if (failure != null) {
          return AsyncValue<ShareCard?>.error(
            failure,
            read.stackTrace ?? StackTrace.empty,
          );
        }
      }

      if (!library.hasValue || !log.hasValue) {
        return const AsyncValue<ShareCard?>.loading();
      }

      final List<Mountain> peaks = library.requireValue;
      Mountain? peak;
      for (final Mountain row in peaks) {
        if (row.id == mountainId) {
          peak = row;
          break;
        }
      }

      // A peak that is not in the library has nothing to share. The screen
      // above has already answered that miss with its own not-found branch.
      if (peak == null) return const AsyncValue<ShareCard?>.data(null);

      return AsyncValue<ShareCard?>.data(
        ShareCard.from(
          peak: peak,
          climbs: log.requireValue,
          libraryTotal: peaks.length,
        ),
      );
    });

/// Hands a rendered card to the platform's share sheet.
///
/// Not auto-disposed, for the reason `MarkClimbedController` is not: the sheet
/// can be swiped away while the platform is still deciding, and a controller
/// disposed underneath its own await would throw on the way back.
final shareCardControllerProvider =
    AsyncNotifierProvider<ShareCardController, void>(ShareCardController.new);

/// The app's one path out to another app.
///
/// [AsyncNotifier] rather than a plain [Notifier] because handing over is real
/// work with a wait in the middle: the state carries loading and error, which
/// is what lets the sheet show a busy button and refuse a second tap while the
/// system sheet is coming up.
class ShareCardController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Renders [card] and shares it. Returns false when nothing was handed over.
  ///
  /// [render] is passed in rather than done here because painting belongs to
  /// the widget layer: the picture is a real widget on a real screen and the
  /// bytes come off its own layer. A null answer means the card was not on
  /// screen to photograph.
  ///
  /// Both halves sit inside one try on purpose. A card that would not render
  /// and a platform that refused it are the same event to the person holding
  /// the phone, and the sheet has one line to say so.
  Future<bool> share({
    required ShareCard card,
    required Future<Uint8List?> Function() render,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final Uint8List? png = await render();
      if (png == null) {
        throw StateError('the share card was not on screen to be rendered');
      }

      await ref
          .read(shareSheetProvider)
          .shareImage(png: png, filename: card.filename, message: card.message);

      state = const AsyncValue<void>.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }
}
