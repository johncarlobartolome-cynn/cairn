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
  late ProviderContainer container;

  setUp(() {
    documents = createTempDirectory('documents');
    picked = createTempDirectory('picked');
    picker = FakePhotoPicker();
    container = ProviderContainer(
      overrides: <Override>[
        documentsDirectoryOverride(documents),
        photoPickerProvider.overrideWithValue(picker),
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

  ClimbPhotoDraft draft() =>
      container.read(climbPhotoDraftProvider.notifier);

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

    draft().keep();
    sub.close();
    await pumpEventQueue();

    expect(filesOnDisk(), saved);
  });
}
