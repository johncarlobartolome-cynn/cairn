import 'dart:io';

import 'package:cairn/data/photos/photo_filename.dart';
import 'package:cairn/data/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';

/// The copy step: the picker's temporary file becomes a file the app owns, and
/// what comes back is a name rather than a place.
void main() {
  late Directory documents;
  late Directory picked;
  late PhotoStore store;

  setUp(() {
    documents = createTempDirectory('documents');
    picked = createTempDirectory('picked');
    store = PhotoStore(directory: () async => documents);
  });

  File stored(String filename) =>
      File('${documents.path}${Platform.pathSeparator}$filename');

  test('copies the file in and hands back a bare filename', () async {
    final File source = writePickedFile(picked, 'IMG_0431.jpg');

    final String filename = await store.copyIn(source.path);

    expect(isBarePhotoFilename(filename), isTrue);
    expect(stored(filename).existsSync(), isTrue);
    expect(stored(filename).readAsBytesSync(), source.readAsBytesSync());
  });

  test('the copy outlives the file the picker handed over', () async {
    // The whole reason for copying. The picker's file sits in a cache the OS
    // may empty whenever it wants the space back.
    final File source = writePickedFile(picked, 'IMG_0431.jpg');
    final String filename = await store.copyIn(source.path);

    source.deleteSync();

    expect(stored(filename).existsSync(), isTrue);
  });

  test('the same photo picked twice lands on two names', () async {
    final File source = writePickedFile(picked, 'IMG_0431.jpg');

    final String first = await store.copyIn(source.path);
    final String second = await store.copyIn(source.path);

    expect(first, isNot(second));
    expect(stored(first).existsSync(), isTrue);
    expect(stored(second).existsSync(), isTrue);
  });

  test('a hundred photos in a row collide on nothing', () async {
    // Names carry a microsecond stamp, and a loop like this is fast enough to
    // put several inside the same microsecond. That is what the random suffix
    // and the free-name check are for.
    final File source = writePickedFile(picked, 'IMG_0431.jpg');

    final Set<String> names = <String>{};
    for (var i = 0; i < 100; i++) {
      names.add(await store.copyIn(source.path));
    }

    expect(names, hasLength(100));
    expect(documents.listSync(), hasLength(100));
  });

  group('the extension is the only thing taken from the picked name', () {
    const Map<String, String> cases = <String, String>{
      'IMG_0431.jpg': '.jpg',
      'IMG_0431.JPG': '.jpg',
      'sunrise.png': '.png',
      'sunrise.heic': '.heic',
      'no-dot-at-all': '.jpg',
      'trailing.': '.jpg',
      '.hidden': '.jpg',
      'weird.thisisnotanextension': '.jpg',
    };

    cases.forEach((String source, String expected) {
      test('$source keeps $expected', () async {
        final String filename = await store.copyIn(
          writePickedFile(picked, source).path,
        );
        expect(filename.endsWith(expected), isTrue, reason: filename);
      });
    });
  });

  test('a source name carrying a path cannot smuggle one into the store', () async {
    // Nothing of the source name survives except a checked extension, so this
    // is belt and braces. It is also the exact shape of the mistake the whole
    // ticket is about.
    final Directory nested = Directory(
      '${picked.path}${Platform.pathSeparator}deeper',
    )..createSync();
    final File source = writePickedFile(nested, 'IMG_0431.jpg');

    final String filename = await store.copyIn(source.path);

    expect(isBarePhotoFilename(filename), isTrue);
    expect(filename, isNot(contains(picked.path)));
  });

  test('a picked file that is already gone throws rather than storing a name', () async {
    final File source = writePickedFile(picked, 'IMG_0431.jpg')..deleteSync();

    await expectLater(
      store.copyIn(source.path),
      throwsA(isA<FileSystemException>()),
    );
    expect(documents.listSync(), isEmpty);
  });

  test('creates the documents directory if it is not there yet', () async {
    documents.deleteSync(recursive: true);

    final String filename = await store.copyIn(
      writePickedFile(picked, 'IMG_0431.jpg').path,
    );

    expect(stored(filename).existsSync(), isTrue);
  });

  group('remove', () {
    test('deletes the stored copy', () async {
      final String filename = await store.copyIn(
        writePickedFile(picked, 'IMG_0431.jpg').path,
      );

      await store.remove(filename);

      expect(stored(filename).existsSync(), isFalse);
    });

    test('a file already gone is not an error', () async {
      await expectLater(store.remove('climb_never_existed.jpg'), completes);
    });

    test('refuses to act on anything that is not a bare filename', () async {
      // Otherwise a bug elsewhere turns a delete into a delete of whatever the
      // path happens to point at.
      final File outsider = writePickedFile(picked, 'someone-elses.jpg');

      await store.remove(outsider.path);

      expect(outsider.existsSync(), isTrue);
    });

    test('removeAll keeps going past one that is already gone', () async {
      final String kept = await store.copyIn(
        writePickedFile(picked, 'a.jpg').path,
      );
      final String alsoKept = await store.copyIn(
        writePickedFile(picked, 'b.jpg').path,
      );

      await store.removeAll(<String>[kept, 'climb_never_existed.jpg', alsoKept]);

      expect(documents.listSync(), isEmpty);
    });
  });

  test('resolve answers against the directory as it is now', () async {
    final String filename = await store.copyIn(
      writePickedFile(picked, 'IMG_0431.jpg').path,
    );

    expect(await store.resolve(filename), stored(filename).path);
  });

  test('a store pointed somewhere else resolves the same name there', () async {
    // What a reinstall does, in one line. The name is unchanged and the answer
    // moves with the directory, because the directory is asked for on the call
    // rather than remembered.
    final Directory moved = createTempDirectory('moved');
    final String filename = await store.copyIn(
      writePickedFile(picked, 'IMG_0431.jpg').path,
    );

    final PhotoStore after = PhotoStore(directory: () async => moved);

    expect(
      await after.resolve(filename),
      '${moved.path}${Platform.pathSeparator}$filename',
    );
  });
}
