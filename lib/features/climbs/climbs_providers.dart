import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// The app's write path for climbs. Nothing else inserts a row.
///
/// The layer rule is `UI → provider → DAO → table`, and the architecture note
/// has always said a widget must never call a DAO. Nothing enforced it: T8's
/// review found that `data/providers.dart` exports `climbDaoProvider` publicly,
/// and this epic is the first that could walk through that hole. So the sheet
/// calls [MarkClimbedController.save] and `test/architecture/layer_rule_test.dart`
/// keeps the widget layer honest.
///
/// Not auto-disposed. The sheet can be swiped away while a save is in flight,
/// and a controller that disposed underneath its own await would throw on the
/// way back. Living for the app's lifetime costs one object and removes that
/// race entirely.
final markClimbedControllerProvider =
    AsyncNotifierProvider<MarkClimbedController, void>(
      MarkClimbedController.new,
    );

/// Logs a climb against a peak.
///
/// [AsyncNotifier] rather than a plain [Notifier] because the write is a
/// database round trip: the state carries loading and error, which is what lets
/// the sheet show a busy button and refuse a second tap.
///
/// It holds no result. Reads are Drift `watch()` streams, so a screen showing
/// climbs updates itself off the insert with no invalidation and nothing to
/// hand back here.
class MarkClimbedController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Writes one climb and returns what the save produced, or null when the
  /// write failed.
  ///
  /// [date] is a calendar day. The caller passes the day the user picked and
  /// the column's converter drops anything below it, so the clock time riding
  /// along on a `DateTime` never reaches the file.
  ///
  /// [companions] and [notes] are optional. Blank is the same as absent, so a
  /// field the user tabbed through stores as null rather than as an empty
  /// string that later renders as an empty line.
  ///
  /// [photoFilenames] comes from [ClimbPhotoDraft], which has already copied
  /// each photo into the documents directory. Bare filenames, never paths. The
  /// column's converter refuses a path outright, so this call fails and the
  /// sheet stays open rather than the app storing a photo it will not be able
  /// to find later.
  ///
  /// Badges unlock as part of this save rather than after it. The peak's own
  /// badge and any milestone the climb just crossed are written in the same
  /// transaction as the climb, so a save that earns two badges is still one
  /// thing the user did and a failure part way leaves neither. Nothing about
  /// that reaches a widget: the sheet calls this, this calls the DAO, and
  /// `test/architecture/layer_rule_test.dart` keeps it that way.
  ///
  /// **Which badges fired travels back with the row id**, and that is the whole
  /// reason this returns more than an id. The sheet says what was earned in the
  /// moment it was earned, and the only place that knows is the write: an
  /// unlock ignores a badge already in the file, so a badge count read
  /// afterwards cannot tell a first climb from a fourth.
  Future<ClimbLogged?> save({
    required int mountainId,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final ClimbLogged saved = await ref
          .read(climbDaoProvider)
          .logClimb(
            mountainId: mountainId,
            date: date,
            companions: _filled(companions),
            notes: _filled(notes),
            photoFilenames: photoFilenames,
          );
      state = const AsyncValue<void>.data(null);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return null;
    }
  }
}

/// The text of a field someone actually filled in, or null.
String? _filled(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// The photos attached to the sheet that is open right now.
///
/// Auto-disposed, so opening the sheet a second time starts empty rather than
/// carrying the last climb's photos into this one.
final climbPhotoDraftProvider =
    AsyncNotifierProvider.autoDispose<ClimbPhotoDraft, List<String>>(
      ClimbPhotoDraft.new,
    );

/// Picks photos and copies them somewhere the app can keep them.
///
/// The copy happens the moment a photo is picked, not when the climb is saved.
/// The picker hands back a file in a cache directory the OS may reclaim at any
/// time, so the earliest safe moment to take a copy is the only sensible one.
/// It also means the thumbnails in the sheet render from the stored file
/// through the same resolve path as climb detail, so what you see before saving
/// is what the app will find afterwards.
///
/// The cost of copying early is a file on disk for a sheet nobody saved, and
/// that is what [keep] is for. A save calls it, and the copies belong to a
/// climb from then on. Anything else, a swipe away or a back press, disposes
/// this provider with [keep] never called, and the copies are deleted on the
/// way out.
///
/// State is [AsyncValue] because copying is real disk work: the sheet shows
/// what is already attached while the next one arrives, and a failure lands
/// as a line the user can read instead of an exception.
class ClimbPhotoDraft extends AutoDisposeAsyncNotifier<List<String>> {
  /// Held rather than looked up on demand, because the cleanup below runs while
  /// this provider is being disposed and `ref` is closed by then.
  late PhotoStore _store;

  /// The attached photos, in the order they were picked. The source of truth;
  /// `state` is a snapshot of it.
  final List<String> _filenames = <String>[];

  /// Set once a climb row is holding these filenames. Until then the files are
  /// this sheet's litter and it clears up after itself.
  bool _kept = false;

  @override
  FutureOr<List<String>> build() {
    _store = ref.read(photoStoreProvider);
    ref.onDispose(_dropUnkept);
    return _snapshot();
  }

  /// Opens the picker and copies whatever comes back.
  ///
  /// A dismissed picker returns nothing and changes nothing, which is not a
  /// failure. A copy that fails part way keeps the photos that did land: half
  /// the photos is a better answer than none of them, and the message says
  /// something went wrong either way.
  Future<void> addFromPicker() async {
    final PhotoPicker picker = ref.read(photoPickerProvider);
    state = const AsyncValue<List<String>>.loading().copyWithPrevious(state);

    try {
      final List<String> sources = await picker.pick();
      for (final String source in sources) {
        _filenames.add(await _store.copyIn(source));
      }
      state = AsyncValue<List<String>>.data(_snapshot());
    } catch (error, stackTrace) {
      state = AsyncValue<List<String>>.error(
        error,
        stackTrace,
      ).copyWithPrevious(AsyncValue<List<String>>.data(_snapshot()));
    }
  }

  /// Drops one photo from the sheet and deletes the copy.
  ///
  /// Safe to delete outright: no row points at it yet, so nothing else can be
  /// showing it.
  Future<void> remove(String filename) async {
    if (!_filenames.remove(filename)) return;
    state = AsyncValue<List<String>>.data(_snapshot());
    await _store.removeAll(<String>[filename]);
  }

  /// Says a climb row now holds these filenames, so they are not litter.
  ///
  /// Called after the write comes back with a row id, never before. A save that
  /// failed leaves the sheet open with the photos still on it, and they are
  /// still this sheet's to clear up.
  void keep() => _kept = true;

  List<String> _snapshot() => List<String>.unmodifiable(_filenames);

  void _dropUnkept() {
    if (_kept || _filenames.isEmpty) return;
    // Nothing is waiting on this and there is no screen left to tell. Fire it
    // and let it finish after the provider is gone.
    unawaited(_store.removeAll(List<String>.of(_filenames)));
  }
}
