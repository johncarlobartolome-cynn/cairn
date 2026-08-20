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
/// database round trip: the state carries loading and error, and the sheet draws
/// its busy button off the loading.
///
/// **The state does not refuse a second tap.** This comment said it did from T15
/// until T31, and a comment overstating a guarantee is how the duplicate stayed
/// invisible. A widget only reads this through a rebuild, so the button starts
/// ignoring presses on the frame after the first tap, and two taps inside one
/// frame both land on the tree that was still idle. Both walked through [save]
/// and each wrote a row. The guard is a synchronous flag in
/// `mark_climbed_sheet.dart`, checked before that method awaits anything.
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
  /// **Null means the write failed and nothing else.** Two calls write two rows,
  /// because a peak climbed twice on one day is two climbs and nothing about a
  /// climb is unique. Deciding that a second tap is not a second climb belongs to
  /// the caller, and it has to, since a refusal reported from here would arrive
  /// as the same null a failure gives and the sheet would say the save failed.
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

/// The write path for an edit to a climb that is already in the log.
///
/// Separate from [markClimbedControllerProvider] because the two writes answer
/// different questions and say different things. A save can earn badges and has
/// to name them; an edit cannot earn one, so it has nothing to hand back but
/// whether it landed. One controller doing both would carry the insert's return
/// type through a path that never fills it in.
///
/// Not auto-disposed, for the reason the save controller is not: the sheet can
/// be swiped away while a write is in flight.
final editClimbControllerProvider =
    AsyncNotifierProvider<EditClimbController, void>(EditClimbController.new);

/// Rewrites one climb.
///
/// The counterpart of [MarkClimbedController], and deliberately the plainer of
/// the two. It writes four fields and reports whether a row moved.
///
/// **The state does not refuse a second tap**, exactly as the save controller's
/// does not. A widget reads this through a rebuild, so the button starts
/// ignoring presses one frame late, and one frame is long enough for a thumb.
/// The guard is a synchronous flag in `mark_climbed_sheet.dart`.
class EditClimbController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Writes the edit and says whether it landed.
  ///
  /// **False covers both ways it can fail**, and they are the same thing to the
  /// person holding the phone. The write threw, or it found no row to change
  /// because the climb is gone. Either way the sheet stays open with everything
  /// still in it and says the changes did not save.
  ///
  /// [date] is a calendar day, and stays one through an edit: the column's
  /// converter drops whatever clock time rides along on the [DateTime] the
  /// picker handed back.
  ///
  /// Blank [companions] and [notes] store as null, the same as on a first save,
  /// so a field somebody cleared reads back as absent rather than as an empty
  /// line on climb detail.
  ///
  /// No badge is unlocked or reported. See [ClimbDao.updateClimb] for why an
  /// edit cannot earn one.
  Future<bool> save({
    required int id,
    required DateTime date,
    String? companions,
    String? notes,
    List<String> photoFilenames = const <String>[],
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final bool changed = await ref
          .read(climbDaoProvider)
          .updateClimb(
            id: id,
            date: date,
            companions: _filled(companions),
            notes: _filled(notes),
            photoFilenames: photoFilenames,
          );
      state = const AsyncValue<void>.data(null);
      return changed;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
    }
  }
}

/// The write path that takes a climb out of the log.
///
/// Separate from the other two for the reason they are separate from each other:
/// the three writes answer different questions. A save can earn badges and has
/// to name them, an edit can earn none, and a delete can take them away and says
/// nothing about it.
///
/// Not auto-disposed, for the reason the other two are not: the screen that
/// asked can be gone before the write comes back.
final deleteClimbControllerProvider =
    AsyncNotifierProvider<DeleteClimbController, void>(
      DeleteClimbController.new,
    );

/// Deletes one climb, its photographs, and any badge it was holding up.
///
/// **The state does not refuse a second tap**, exactly as the other two do not.
/// A widget reads this through a rebuild, so a control starts ignoring presses
/// one frame late, and one frame is long enough for a thumb. The guard is a
/// synchronous flag in `widgets/delete_climb_action.dart`, checked before the
/// confirmation is even opened.
class DeleteClimbController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Deletes the climb and says whether it went.
  ///
  /// **False covers both ways it can fail**, and they are the same thing to the
  /// person holding the phone: the write threw, or there was no such climb to
  /// delete. Either way nothing was taken away, so the screen stays where it is
  /// and says the climb is still there.
  ///
  /// **The photo files go after the row does, never before, and only once the
  /// transaction has committed.** A file deletion cannot be rolled back, so
  /// doing it first would mean a write that failed had already taken the
  /// photographs off a climb still sitting in the log. This order can leave a
  /// file behind instead, which is litter in the documents directory and costs
  /// the user nothing.
  ///
  /// The deletion is awaited rather than fired and forgotten, unlike the photo
  /// draft's cleanup. That cleanup runs while a provider is being disposed with
  /// nothing left to tell; this one has a caller waiting on an answer, and the
  /// answer is more honest if the files really are gone by the time it arrives.
  /// [PhotoStore.removeAll] steps over a file that is already gone and keeps
  /// going past one it cannot delete, so a stubborn file cannot turn a
  /// successful delete into a failed one.
  ///
  /// No badge is named on the way out. See [ClimbRemoved] for why the app stays
  /// quiet about what a delete revoked.
  Future<bool> delete({required int id}) async {
    state = const AsyncValue<void>.loading();
    try {
      final ClimbRemoved? removed = await ref
          .read(climbDaoProvider)
          .deleteClimb(id: id);
      if (removed == null) {
        state = const AsyncValue<void>.data(null);
        return false;
      }

      if (removed.photoFilenames.isNotEmpty) {
        await ref.read(photoStoreProvider).removeAll(removed.photoFilenames);
      }
      state = const AsyncValue<void>.data(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return false;
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
///
/// **On an edit the draft starts from the row's own photos**, seeded through
/// [climbPhotoDraftSeedProvider]. Those files are not this sheet's to delete, so
/// the bookkeeping splits in two: a photo this sheet copied goes the moment it
/// is taken off, and a photo the climb arrived with goes only once the edit is
/// saved. An edit that is cancelled leaves every photograph where it was.
class ClimbPhotoDraft extends AutoDisposeAsyncNotifier<List<String>> {
  /// [existing] are the photos the climb being edited already holds.
  ///
  /// Empty for a new climb, which is every caller but one: the sheet's edit path
  /// overrides [climbPhotoDraftProvider] inside a scope of its own with a draft
  /// built this way, so the row's photographs are on the sheet before anything
  /// draws.
  ///
  /// **Handed to the notifier rather than called in after the fact.** The draft
  /// is auto-disposed, so a notifier read from a widget's `initState` with
  /// nobody listening yet can be thrown away before the first build, and a seed
  /// pushed into it would go with it. Arriving through the constructor cannot
  /// lose that race: a draft made again is made with the same photos.
  ClimbPhotoDraft({List<String> existing = const <String>[]})
    : _seed = existing;

  final List<String> _seed;

  /// Held rather than looked up on demand, because the cleanup below runs while
  /// this provider is being disposed and `ref` is closed by then.
  late PhotoStore _store;

  /// The attached photos, in the order they were picked. The source of truth;
  /// `state` is a snapshot of it.
  final List<String> _filenames = <String>[];

  /// The picks still copying. A save waits on these rather than reading past
  /// them; see [settled].
  ///
  /// It is also the guard against a second tap on the add row, because it is the
  /// one record of whether a pick is already running. A flag beside it would be
  /// the same fact kept twice, and the two would drift.
  final List<Future<void>> _copying = <Future<void>>[];

  /// The filenames a climb row is holding. Anything copied by this sheet and
  /// not in here is litter, and the sheet clears it up on the way out.
  final Set<String> _kept = <String>{};

  /// The photos the climb being edited arrived with.
  ///
  /// **These are not this sheet's files.** A climb row names them, so an edit
  /// that is abandoned has to leave every one of them exactly where it is. They
  /// go into [_kept] the moment they are adopted, which is what makes the
  /// cleanup on the way out step over them.
  final Set<String> _existing = <String>{};

  /// Photos the row still names that the user has taken off the sheet.
  ///
  /// Held rather than deleted. Taking a photo off an edit is a decision about a
  /// climb that already exists, so the file goes when the edit is saved and
  /// never before: a cancelled edit has to leave the climb exactly as it was,
  /// photographs included. This is the whole of what T30's cleanup could not do,
  /// because it was written for a row that did not exist yet.
  final Set<String> _dropped = <String>{};

  /// True once a seed has been taken, so a rebuild cannot pull the photos the
  /// user has since removed back onto the sheet.
  bool _adopted = false;

  /// Set the moment the sheet is gone. A copy already in the air cannot be
  /// called back, so it checks this when it lands.
  bool _gone = false;

  @override
  FutureOr<List<String>> build() {
    _store = ref.read(photoStoreProvider);
    ref.onDispose(_dropUnkept);
    _adopt(_seed);
    return _snapshot();
  }

  /// Starts the draft from the photos a climb already holds.
  ///
  /// Once only. They are recorded as kept in the same breath, because the
  /// cleanup that runs when this sheet goes deletes what the sheet is holding
  /// and nobody is keeping, and these belong to a row rather than to the sheet.
  void _adopt(List<String> existing) {
    if (_adopted) return;
    _adopted = true;
    if (existing.isEmpty) return;

    _filenames.addAll(existing);
    _existing.addAll(existing);
    _kept.addAll(existing);
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
  ///
  /// **A call made while a pick is already running does nothing at all.** The add
  /// row greys itself out off a rebuild, so it starts ignoring presses on the
  /// frame after the first tap, and two taps inside one frame both land on the
  /// row that was still live. Both opened the system picker and both started a
  /// copy run, which is the same photos copied twice and the picker put in front
  /// of somebody who had already chosen.
  ///
  /// The guard is here rather than on the widget for two reasons. The refusal is
  /// silent either way, so there is nothing for a widget to decide: this returns
  /// void, a refused call publishes no error, and the row looks exactly as it did.
  /// And `ClimbPhotoField` is a `ConsumerWidget`, so a flag there would be a
  /// second copy of a fact this class already keeps, one rebuild behind it.
  ///
  /// [_copying] is read and written with nothing between them that can yield, so
  /// the second of two taps in one frame cannot get past the check: the list is
  /// non-empty by the time this call returns, and Dart runs the next tap's
  /// handler after that.
  Future<void> addFromPicker() {
    if (_copying.isNotEmpty) return Future<void>.value();

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

  /// Drops one photo from the sheet.
  ///
  /// **Whether the file goes with it depends on whose file it is.** One this
  /// sheet copied has no row pointing at it, so it is deleted here and nothing
  /// can be left showing it. One the climb arrived with is still on a saved
  /// climb until the edit lands, so it is only remembered here and deleted by
  /// [keep]. Delete it now and a cancelled edit would have taken a photograph
  /// off a climb it never changed.
  Future<void> remove(String filename) async {
    if (!_filenames.remove(filename)) return;
    state = AsyncValue<List<String>>.data(_snapshot());

    if (_existing.contains(filename)) {
      // Out of [_kept] as well, or [keep] would spare it: adoption put every
      // photo the row arrived with in there, and this one is on its way out.
      // Nothing on the cancel path reads [_kept] for a photo already off the
      // sheet, so this cannot cost a file an abandoned edit has to leave alone.
      _kept.remove(filename);
      _dropped.add(filename);
      return;
    }
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
  ///
  /// **This is also the moment a photo taken off an edit is deleted**, and the
  /// earliest one there is. Until the write came back the row still named it.
  /// Anything the row now holds is spared even if it was dropped and picked
  /// again, since the names are what decide rather than the order of the taps.
  ///
  /// The deletion is not waited for, the same as the cleanup on the way out.
  /// Nothing on screen is waiting for a file to go, and the sheet is closing.
  void keep(Iterable<String> filenames) {
    _kept.addAll(filenames);

    final List<String> gone = <String>[
      for (final String filename in _dropped)
        if (!_kept.contains(filename)) filename,
    ];
    _dropped.clear();
    if (gone.isEmpty) return;

    unawaited(_store.removeAll(gone));
  }

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
