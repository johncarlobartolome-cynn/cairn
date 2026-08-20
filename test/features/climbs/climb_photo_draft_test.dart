import 'dart:io';

import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/climbs_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';

/// The draft the mark-climbed sheet holds while it is open.
///
/// Copying happens on the pick rather than on the save, because the file the
/// picker hands over lives in a cache the OS may empty at any moment. The cost
/// of copying early is a file on disk for a sheet nobody saved, so the draft
/// clears up after itself unless a climb row took the filenames.
void main() {
  late Directory documents;
  late Directory picked;
  late FakePhotoPicker picker;

  /// The real store with a valve on it. Left open unless a test is about the
  /// window a copy is in flight, which is the window T30 was about.
  late HeldPhotoStore store;

  late ProviderContainer container;

  setUp(() {
    documents = createTempDirectory('documents');
    picked = createTempDirectory('picked');
    picker = FakePhotoPicker();
    store = HeldPhotoStore(documents);
    container = ProviderContainer(
      overrides: <Override>[
        documentsDirectoryOverride(documents),
        photoPickerProvider.overrideWithValue(picker),
        photoStoreOverride(store),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Subscribes, the way the sheet does. Without a listener the provider is
  /// disposed the instant it is read, which is the behaviour under test in two
  /// of these and would wreck the rest.
  ProviderSubscription<AsyncValue<List<String>>> open() {
    final sub = container.listen<AsyncValue<List<String>>>(
      climbPhotoDraftProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sub.close);
    return sub;
  }

  ClimbPhotoDraft draft() => container.read(climbPhotoDraftProvider.notifier);

  List<String> attached() =>
      container.read(climbPhotoDraftProvider).valueOrNull ?? const <String>[];

  List<String> filesOnDisk() => <String>[
    for (final FileSystemEntity entity in documents.listSync())
      entity.path.split(Platform.pathSeparator).last,
  ]..sort();

  test('starts with nothing attached', () {
    open();
    expect(attached(), isEmpty);
  });

  test('picking copies each file in and holds the bare filenames', () async {
    open();
    picker.paths = <String>[
      writePickedFile(picked, 'IMG_0431.jpg').path,
      writePickedFile(picked, 'IMG_0432.png').path,
    ];

    await draft().addFromPicker();

    expect(attached(), hasLength(2));
    expect(filesOnDisk(), attached().toList()..sort());
    for (final String name in attached()) {
      expect(name, isNot(contains(Platform.pathSeparator)));
      expect(name, isNot(contains(picked.path)));
    }
  });

  test('the attached copy outlives the file the picker handed over', () async {
    open();
    final File source = writePickedFile(picked, 'IMG_0431.jpg');
    picker.paths = <String>[source.path];

    await draft().addFromPicker();
    source.deleteSync();

    expect(filesOnDisk(), attached());
  });

  test('picking twice adds to what is already there', () async {
    open();
    picker.paths = <String>[writePickedFile(picked, 'a.jpg').path];
    await draft().addFromPicker();

    picker.paths = <String>[writePickedFile(picked, 'b.jpg').path];
    await draft().addFromPicker();

    expect(attached(), hasLength(2));
    expect(picker.openings, 2);
  });

  test('a picker dismissed without choosing changes nothing', () async {
    open();
    picker.paths = const <String>[];

    await draft().addFromPicker();

    expect(attached(), isEmpty);
    expect(container.read(climbPhotoDraftProvider).hasError, isFalse);
  });

  test('removing one drops it and deletes the copy', () async {
    open();
    picker.paths = <String>[
      writePickedFile(picked, 'a.jpg').path,
      writePickedFile(picked, 'b.jpg').path,
    ];
    await draft().addFromPicker();

    final String dropped = attached().first;
    await draft().remove(dropped);

    expect(attached(), hasLength(1));
    expect(attached(), isNot(contains(dropped)));
    expect(filesOnDisk(), attached());
  });

  test('a failed pick is reported and keeps whatever did land', () async {
    open();
    picker.paths = <String>[writePickedFile(picked, 'a.jpg').path];
    await draft().addFromPicker();

    picker.failure = const FileSystemException('picker gave up');
    await draft().addFromPicker();

    final AsyncValue<List<String>> state = container.read(
      climbPhotoDraftProvider,
    );
    expect(state.hasError, isTrue);
    // The photo from the first pick is still attached and still on disk. Half
    // the photos beats none of them.
    expect(state.valueOrNull, hasLength(1));
    expect(filesOnDisk(), hasLength(1));
  });

  test('a sheet closed without saving takes its copies with it', () async {
    // The other side of copying early. Nothing points at these files, so
    // leaving them behind would be litter that grows every time somebody opens
    // the sheet and changes their mind.
    final sub = open();
    picker.paths = <String>[
      writePickedFile(picked, 'a.jpg').path,
      writePickedFile(picked, 'b.jpg').path,
    ];
    await draft().addFromPicker();
    expect(filesOnDisk(), hasLength(2));

    sub.close();
    await pumpEventQueue();

    expect(filesOnDisk(), isEmpty);
  });

  test('a saved climb keeps its photos when the sheet goes', () async {
    // keep() is called by the sheet after the row comes back with an id, so
    // the files belong to a climb from then on and the cleanup leaves them be.
    final sub = open();
    picker.paths = <String>[writePickedFile(picked, 'a.jpg').path];
    await draft().addFromPicker();
    final List<String> saved = attached();

    draft().keep(saved);
    sub.close();
    await pumpEventQueue();

    expect(filesOnDisk(), saved);
  });

  /// The window a copy is in flight, which nothing tested before T30.
  ///
  /// A copy is over in a millisecond, so these hold it still rather than racing
  /// it: the store parks each copy until the test lets it land, and the draft is
  /// read in between.
  group('while a pick is still copying', () {
    /// Two picked files waiting to be copied, with the store holding them.
    void holdTwo() {
      store.holdCopies();
      picker.paths = <String>[
        writePickedFile(picked, 'a.jpg').path,
        writePickedFile(picked, 'b.jpg').path,
      ];
    }

    test('each copy is published as it lands, not all at the end', () async {
      open();
      holdTwo();

      final Future<void> pick = draft().addFromPicker();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the first copy to be parked',
      );
      expect(attached(), isEmpty);

      store.letOneThrough();
      // Waiting for the second copy to park is how this knows the first one
      // finished, so what is attached by now is not a guess.
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the second copy to be parked',
      );
      expect(attached(), hasLength(1), reason: 'the first copy has landed');

      store.letOneThrough();
      await pick;
      expect(attached(), hasLength(2));
    });

    test('it says it is still working until the last copy lands', () async {
      open();
      holdTwo();

      final Future<void> pick = draft().addFromPicker();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the first copy to be parked',
      );
      expect(container.read(climbPhotoDraftProvider).isLoading, isTrue);

      store.letOneThrough();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the second copy to be parked',
      );
      expect(
        container.read(climbPhotoDraftProvider).isLoading,
        isTrue,
        reason: 'one of two has landed, so it is still working',
      );

      store.letEverythingThrough();
      await pick;
      expect(container.read(climbPhotoDraftProvider).isLoading, isFalse);
    });

    test('the filenames a save reads wait for the copies in flight', () async {
      // What the sheet asks for. Nothing has landed at the moment the save
      // arrives, and it still comes away with both photos.
      open();
      holdTwo();

      final Future<void> pick = draft().addFromPicker();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the first copy to be parked',
      );
      expect(attached(), isEmpty);

      final Future<List<String>> settling = draft().settled();
      store.letEverythingThrough();

      expect(await settling, hasLength(2));
      await pick;
    });

    test('a second pick while one is still copying is refused', () async {
      // The T32 double tap, at the layer the guard is on. The add row greys
      // itself out off a rebuild, so two taps in one frame both reach here, and
      // the second one opened the picker again and copied the same files a
      // second time.
      open();
      holdTwo();

      final Future<void> pick = draft().addFromPicker();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the first copy to be parked',
      );

      // Not awaited. A refused call answers at once, and one that got through
      // would be waiting on a copy this test is still holding.
      final Future<void> refused = draft().addFromPicker();
      expect(picker.openings, 1);

      store.letEverythingThrough();
      await Future.wait<void>(<Future<void>>[pick, refused]);

      expect(attached(), hasLength(2));
      expect(filesOnDisk(), hasLength(2));
    });

    test('a copy that lands after the sheet is gone is not left behind', () async {
      // The sheet cannot call a copy back once it is reading bytes, so the copy
      // checks on the way out instead. Without that, closing the sheet during a
      // pick left a file in the documents directory with nothing pointing at it.
      final sub = open();
      holdTwo();

      final Future<void> pick = draft().addFromPicker();
      await waitUntil(
        () => store.waiting == 1,
        waitingFor: 'the first copy to be parked',
      );
      store.letOneThrough();
      await waitUntil(
        () => filesOnDisk().length == 1,
        waitingFor: 'the first copy to land',
      );

      sub.close();
      store.letEverythingThrough();
      await pick;
      await waitUntil(
        () => filesOnDisk().isEmpty,
        waitingFor: 'both copies to be cleared up',
      );

      expect(filesOnDisk(), isEmpty);
    });
  });

  /// The draft as the edit path builds it: starting from the photos a climb
  /// already holds.
  ///
  /// **These files are not the sheet's**, and that is the whole of what changes.
  /// T30's cleanup was written for a row that did not exist yet, so it deletes a
  /// copy the moment it is taken off. Do that on a climb already in the log and
  /// an edit somebody abandoned has taken a photograph with it.
  group('on a climb that already has photos', () {
    late ProviderContainer edit;
    late List<String> existing;

    setUp(() {
      existing = <String>[
        'climb_1755300000000001_a1b2c3d4.jpg',
        'climb_1755300000000002_e5f6a7b8.jpg',
      ];
      for (final String name in existing) {
        writePickedFile(documents, name);
      }
      edit = ProviderContainer(
        overrides: <Override>[
          documentsDirectoryOverride(documents),
          photoPickerProvider.overrideWithValue(picker),
          photoStoreOverride(store),
          climbPhotoDraftProvider.overrideWith(
            () => ClimbPhotoDraft(existing: existing),
          ),
        ],
      );
      addTearDown(edit.dispose);
    });

    ProviderSubscription<AsyncValue<List<String>>> openEdit() {
      final sub = edit.listen<AsyncValue<List<String>>>(
        climbPhotoDraftProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(sub.close);
      return sub;
    }

    ClimbPhotoDraft editDraft() => edit.read(climbPhotoDraftProvider.notifier);

    List<String> editAttached() =>
        edit.read(climbPhotoDraftProvider).valueOrNull ?? const <String>[];

    test('starts from the photos the climb already holds', () {
      openEdit();

      expect(editAttached(), existing);
      expect(filesOnDisk(), existing.toList()..sort());
    });

    test('a photo taken off is kept on disk until the edit is saved', () async {
      openEdit();

      await editDraft().remove(existing.first);

      expect(editAttached(), <String>[existing.last]);
      expect(
        filesOnDisk(),
        existing.toList()..sort(),
        reason: 'the climb still names it, so the file cannot go yet',
      );
    });

    test('and goes the moment the edit is saved', () async {
      openEdit();
      await editDraft().remove(existing.first);

      editDraft().keep(editAttached());
      await waitUntil(
        () => filesOnDisk().length == 1,
        waitingFor: 'the photo the edit dropped to be deleted',
      );

      expect(filesOnDisk(), <String>[existing.last]);
    });

    test('a cancelled edit leaves every photograph where it was', () async {
      // The one that would have cost a photograph. Everything is changed and
      // then thrown away: one of the climb's own photos taken off, another
      // picked, and the sheet closed without saving.
      final sub = openEdit();
      await editDraft().remove(existing.first);

      picker.paths = <String>[writePickedFile(picked, 'late.jpg').path];
      await editDraft().addFromPicker();
      expect(filesOnDisk(), hasLength(3));

      sub.close();
      await waitUntil(
        () => filesOnDisk().length == 2,
        waitingFor: 'the copy nobody saved to be cleared up',
      );

      expect(filesOnDisk(), existing.toList()..sort());
    });

    test('a photo picked during an edit is kept once it is saved', () async {
      final sub = openEdit();
      picker.paths = <String>[writePickedFile(picked, 'new.jpg').path];
      await editDraft().addFromPicker();

      final List<String> saved = editAttached();
      expect(saved, hasLength(3));

      editDraft().keep(saved);
      sub.close();
      await pumpEventQueue();

      expect(filesOnDisk(), saved.toList()..sort());
    });
  });

  test('a photo the saved row does not name goes with the sheet', () async {
    // The pick that got in as the save started. The row was written before this
    // copy landed, so the row does not name it and nothing ever will.
    final sub = open();
    picker.paths = <String>[writePickedFile(picked, 'a.jpg').path];
    await draft().addFromPicker();
    final List<String> written = attached();

    picker.paths = <String>[writePickedFile(picked, 'late.jpg').path];
    await draft().addFromPicker();
    expect(filesOnDisk(), hasLength(2));

    draft().keep(written);
    sub.close();
    await waitUntil(
      () => filesOnDisk().length == 1,
      waitingFor: 'the photo the row does not name to be cleared up',
    );

    expect(filesOnDisk(), written);
  });
}
