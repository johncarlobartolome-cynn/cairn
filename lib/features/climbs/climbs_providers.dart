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
/// that is what [keep] is for. A save calls it with the filenames the row was
/// written with, and those belong to a climb from then on. Everything else this
/// sheet copied is deleted when it is disposed, whether that is a swipe away, a
/// back press, or a photo that landed a moment too late to be saved.
///
/// State is [AsyncValue] because copying is real disk work: the sheet shows
/// what is already attached while the next one arrives, and a failure lands
/// as a line the user can read instead of an exception.
///
/// **Loading here means more are coming, not that there is nothing yet.** Until
/// T30 the state went loading with the list from before the pick underneath it
/// and only grew at the end, so for the length of a pick the published answer
/// was a lie. Everything a save reads now grows as each copy lands, and a save
/// that arrives mid-pick waits for the rest through [settled].
class ClimbPhotoDraft extends AutoDisposeAsyncNotifier<List<String>> {
  /// Held rather than looked up on demand, because the cleanup below runs while
  /// this provider is being disposed and `ref` is closed by then.
  late PhotoStore _store;

  /// The attached photos, in the order they were picked. The source of truth;
  /// `state` is a snapshot of it.
  final List<String> _filenames = <String>[];

  /// The picks still copying. A save waits on these rather than reading past
  /// them; see [settled].
  final List<Future<void>> _copying = <Future<void>>[];

  /// The filenames a climb row is holding. Anything copied by this sheet and
  /// not in here is litter, and the sheet clears it up on the way out.
  final Set<String> _kept = <String>{};

  /// Set the moment the sheet is gone. A copy already in the air cannot be
  /// called back, so it checks this when it lands.
  bool _gone = false;

  @override
  FutureOr<List<String>> build() {
    _store = ref.read(photoStoreProvider);
    ref.onDispose(_dropUnkept);
    return _snapshot();
  }

  /// Every publish reaches the sheet, including one loading state after another.
  ///
  /// [AsyncNotifier] filters those out by default, and the reasoning behind that
  /// default is sound for the usual shape: a provider goes loading once on its
  /// way to data, so a second loading carries nothing new. This one publishes a
  /// photo at a time while staying loading, so the default delivered the first
  /// copy and swallowed every one after it.
  ///
  /// Found by building the incremental publish and watching the sheet ignore it.
  /// The state was already right; nobody was being told. Anything written here is
  /// a real change, so there is nothing left worth filtering.
  @override
  bool updateShouldNotify(
    AsyncValue<List<String>> previous,
    AsyncValue<List<String>> next,
  ) => true;

  /// Opens the picker and copies whatever comes back.
  ///
  /// A dismissed picker returns nothing and changes nothing, which is not a
  /// failure. A copy that fails part way keeps the photos that did land: half
  /// the photos is a better answer than none of them, and the message says
  /// something went wrong either way.
  ///
  /// Each copy is published as it lands rather than all of them at the end, so
  /// a thumbnail appears per photo and the row can keep saying it is working.
  /// The alternative was one publish at the end, which left the sheet looking
  /// idle for as long as the copying took.
  ///
  /// The returned future is the whole run. Nothing in the UI awaits it, which is
  /// why the run is also recorded in [_copying] for [settled] to find.
  Future<void> addFromPicker() {
    final Future<void> run = _pickAndCopy();
    _copying.add(run);
    return run.whenComplete(() => _copying.remove(run));
  }

  /// The run itself, which never throws. Every failure lands on the state as a
  /// line the sheet can show, so a caller awaiting it gets a plain answer.
  Future<void> _pickAndCopy() async {
    final PhotoPicker picker = ref.read(photoPickerProvider);
    _publish(working: true);

    try {
      final List<String> sources = await picker.pick();
      for (final String source in sources) {
        final String filename = await _store.copyIn(source);
        if (_gone) {
          // The sheet went while this copy was in the air. No row can name it
          // and there is no state left to publish it into, so it goes now
          // rather than sitting in the documents directory forever.
          unawaited(_store.removeAll(<String>[filename]));
          return;
        }
        _filenames.add(filename);
        _publish(working: true);
      }
      _publish(working: false);
    } catch (error, stackTrace) {
      if (_gone) return;
      state = AsyncValue<List<String>>.error(
        error,
        stackTrace,
      ).copyWithPrevious(AsyncValue<List<String>>.data(_snapshot()));
    }
  }

  /// The attached photos, and whether more are still coming.
  ///
  /// Loading carries the list rather than standing in front of it, which is what
  /// lets the sheet draw the photos that have landed while it says the rest are
  /// on their way.
  void _publish({required bool working}) {
    final AsyncValue<List<String>> landed = AsyncValue<List<String>>.data(
      _snapshot(),
    );
    state = working
        ? const AsyncValue<List<String>>.loading().copyWithPrevious(landed)
        : landed;
  }

  /// The attached filenames, once every copy already in flight has landed.
  ///
  /// What a save reads. Reading the published list instead is the whole of the
  /// T30 bug: mid-pick that list is the photos copied so far, so a climb saved
  /// in that window was written without the rest of them.
  ///
  /// Only work that had started by the time this was called is waited for. A
  /// pick that begins afterwards belongs to whatever the user does next, and its
  /// copies are cleared up by [keep] naming what the row actually holds.
  Future<List<String>> settled() async {
    await Future.wait<void>(List<Future<void>>.of(_copying));
    return _snapshot();
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

  /// Says which filenames a climb row now holds, so those are not litter.
  ///
  /// Called after the write comes back with a row id, never before. A save that
  /// failed leaves the sheet open with the photos still on it, and they are
  /// still this sheet's to clear up.
  ///
  /// It takes the names rather than setting a flag, and that is the guarantee:
  /// what the row names is kept and anything else this sheet copied is deleted.
  /// A photo picked in the instant the save started is exactly that, since the
  /// row was written before its copy landed.
  void keep(Iterable<String> filenames) => _kept.addAll(filenames);

  List<String> _snapshot() => List<String>.unmodifiable(_filenames);

  void _dropUnkept() {
    // Read by every copy still in the air. One that is already reading bytes
    // cannot be stopped, so it lands and deletes itself instead.
    _gone = true;

    final List<String> litter = <String>[
      for (final String filename in _filenames)
        if (!_kept.contains(filename)) filename,
    ];
    if (litter.isEmpty) return;

    // Nothing is waiting on this and there is no screen left to tell. Fire it
    // and let it finish after the provider is gone.
    unawaited(_store.removeAll(litter));
  }
}
