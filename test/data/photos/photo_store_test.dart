import 'dart:io';
import 'dart:typed_data';

import 'package:cairn/data/photos/photo_cap.dart';
import 'package:cairn/data/photos/photo_filename.dart';
import 'package:cairn/data/photos/photo_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

  group('the cap on the way in', () {
    /// A photograph where the picker would have left one.
    File writePhotograph(
      String name, {
      required int width,
      required int height,
      int orientation = 1,
    }) {
      final File file = File('${picked.path}${Platform.pathSeparator}$name');
      file.writeAsBytesSync(
        photographBytes(width: width, height: height, orientation: orientation),
      );
      return file;
    }

    test('a camera photo lands inside the cap', () async {
      final File source = writePhotograph(
        'IMG_0431.jpg',
        width: 3000,
        height: 2000,
      );

      final String filename = await store.copyIn(source.path);

      final img.Image saved = img.decodeImage(
        stored(filename).readAsBytesSync(),
      )!;
      expect(saved.width, photoLongEdgeCap);
      expect(stored(filename).lengthSync(), lessThan(source.lengthSync()));
      expect(isBarePhotoFilename(filename), isTrue);
    });

    test('a small photo is stored byte for byte', () async {
      final File source = writePhotograph(
        'IMG_0432.jpg',
        width: 800,
        height: 600,
      );

      final String filename = await store.copyIn(source.path);

      expect(stored(filename).readAsBytesSync(), source.readAsBytesSync());
    });

    test('a sideways photo is stored upright', () async {
      final File source = writePhotograph(
        'IMG_0433.jpg',
        width: 3000,
        height: 2000,
        orientation: 6,
      );

      final String filename = await store.copyIn(source.path);

      final img.Image saved = img.decodeImage(
        stored(filename).readAsBytesSync(),
      )!;
      expect(saved.height, greaterThan(saved.width));
      expect(isCornerMark(saved, saved.width - 40, 40), isTrue);
    });
  });

  group('the cap over photos already stored', () {
    /// A photo already in the documents directory, as if E3 had put it there.
    File writeStored(
      String name, {
      required int width,
      required int height,
      bool png = false,
    }) {
      final File file = stored(name);
      file.writeAsBytesSync(
        photographBytes(width: width, height: height, png: png),
      );
      return file;
    }

    test('rewrites an oversized photo under the name it already has', () async {
      final File photo = writeStored(
        'climb_1_aaaaaaaa.jpg',
        width: 3000,
        height: 2000,
      );
      final int before = photo.lengthSync();

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(photo.existsSync(), isTrue, reason: 'same name, same file');
      expect(photo.lengthSync(), lessThan(before));
      expect(img.decodeImage(photo.readAsBytesSync())!.width, photoLongEdgeCap);
      expect(report.scanned, 1);
      expect(report.rewritten, 1);
      expect(report.bytesBefore, before);
      expect(report.bytesAfter, photo.lengthSync());
    });

    test('leaves a photo already inside the cap byte for byte', () async {
      final File photo = writeStored(
        'climb_2_bbbbbbbb.jpg',
        width: 800,
        height: 600,
      );
      final Uint8List before = photo.readAsBytesSync();

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(photo.readAsBytesSync(), before);
      expect(report.rewritten, 0);
      expect(report.bytesBefore, report.bytesAfter);
    });

    test('keeps a PNG a PNG, so the stored name stays true', () async {
      // The reason no row has to change. What a climb holds is a filename,
      // extension included, so the file is rewritten in the format it arrived
      // in and the database never learns this happened.
      final File photo = writeStored(
        'climb_3_cccccccc.png',
        width: 3000,
        height: 2000,
        png: true,
      );

      await store.capStoredPhotos();

      expect(
        img.findFormatForData(photo.readAsBytesSync()),
        img.ImageFormat.png,
      );
    });

    test('changes no filename at all', () async {
      writeStored('climb_4_dddddddd.jpg', width: 3000, height: 2000);
      writeStored('climb_5_eeeeeeee.jpg', width: 640, height: 480);
      final List<String> before = _photoNamesIn(documents);

      await store.capStoredPhotos();

      expect(_photoNamesIn(documents), before);
    });

    test('leaves everything that is not a climb photo alone', () async {
      final File database = stored('cairn.sqlite')
        ..writeAsBytesSync(photographBytes(width: 3000, height: 2000));
      final Uint8List before = database.readAsBytesSync();

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(database.readAsBytesSync(), before);
      expect(report.scanned, 0);
    });

    test('runs once, not on every launch', () async {
      writeStored('climb_6_ffffffff.jpg', width: 3000, height: 2000);

      await store.capStoredPhotos();
      final PhotoCapReport again = await store.capStoredPhotos();

      expect(again.scanned, 0);
    });

    test('sweeps up a rewrite a crash interrupted', () async {
      final File halfWritten = stored('.cairn-writing-climb_7_gggggggg.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);

      await store.capStoredPhotos();

      expect(halfWritten.existsSync(), isFalse);
    });

    test('a failed rewrite leaves the photograph exactly as it was', () async {
      // The guarantee that matters most. A photo is rewritten beside itself and
      // moved onto its own name, so a write that cannot finish never gets as
      // far as touching the original. Proven by taking the directory's write
      // permission away underneath a photo that the cap definitely wants to
      // change.
      final File photo = writeStored(
        'climb_8_hhhhhhhh.jpg',
        width: 3000,
        height: 2000,
      );
      final Uint8List before = photo.readAsBytesSync();
      addTearDown(() => Process.runSync('chmod', ['u+w', documents.path]));
      Process.runSync('chmod', ['u-w', documents.path]);

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(photo.readAsBytesSync(), before, reason: 'the photo is untouched');
      expect(img.decodeImage(photo.readAsBytesSync()), isNotNull);
      expect(report.scanned, 1);
      expect(report.rewritten, 0);
    });

    test('one unreadable photo does not stop the pass', () async {
      stored('climb_9_iiiiiiii.jpg').writeAsBytesSync(<int>[0, 1, 2, 3]);
      final File real = writeStored(
        'climb_a_jjjjjjjj.jpg',
        width: 3000,
        height: 2000,
      );
      final int before = real.lengthSync();

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(real.lengthSync(), lessThan(before));
      expect(report.scanned, 2);
      expect(report.rewritten, 1);
    });

    test('an empty documents directory is not an error', () async {
      documents.deleteSync(recursive: true);

      final PhotoCapReport report = await store.capStoredPhotos();

      expect(report.scanned, 0);
    });
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

/// The climb photos in [directory] by name, sorted, so a test can say nothing
/// was renamed. The pass leaves a marker of its own next to them, which is not
/// a photo and not something a row points at.
List<String> _photoNamesIn(Directory directory) =>
    directory
        .listSync()
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .where((name) => name.startsWith('climb_'))
        .toList()
      ..sort();
