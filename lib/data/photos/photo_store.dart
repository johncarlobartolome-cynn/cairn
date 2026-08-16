import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'photo_cap.dart';
import 'photo_filename.dart';

/// Climb photos on disk.
///
/// The picker hands back a file in a cache directory that the OS is free to
/// reclaim whenever it wants the space, so pointing the database at that file
/// is not storage. [copyIn] takes a copy into the app's own documents
/// directory, which is the app's to keep, and returns the bare filename to
/// store.
///
/// Nothing here ever hands out a path. The directory is looked up again on
/// every call, and every render, because the answer is only true for as long
/// as this install lasts.
class PhotoStore {
  const PhotoStore({required this.directory});

  /// Asked, never remembered. In the app this is the documents directory from
  /// `path_provider`; in a test it is a throwaway directory the test controls.
  ///
  /// A function rather than a value, because the answer is only true for as
  /// long as this install lasts and every caller here has to ask again.
  final Future<Directory> Function() directory;

  /// Leads every generated name, so a stray file in the documents directory is
  /// recognisable as one of ours next to `cairn.sqlite`.
  static const String _prefix = 'climb';

  /// Used when the picked file has no usable extension of its own. The picker
  /// returns JPEG for a camera photo on both platforms, so this guesses in the
  /// most likely direction rather than inventing a format.
  static const String _fallbackExtension = '.jpg';

  /// Long enough that two photos picked inside the same microsecond still land
  /// on different names.
  static const int _suffixLength = 8;

  /// Where a rewritten photo is built before it replaces the one on disk.
  ///
  /// Deliberately outside [_prefix], so the pass below cannot pick a half
  /// written file up as a photo of its own.
  static const String _workingPrefix = '.cairn-writing-';

  /// Remembers which cap the photos in this directory have already been through.
  ///
  /// A file rather than a row, because the photos are files and the database
  /// holds nothing that would change. It carries the cap number rather than a
  /// flag, so raising or lowering [photoLongEdgeCap] later is enough on its own
  /// to make the pass run again over photos it has already seen.
  static const String _capMarker = '.cairn-photo-cap';

  static final Random _random = Random();

  /// Copies the file at [sourcePath] into the documents directory and returns
  /// the bare filename to store against the climb.
  ///
  /// The name is built from a microsecond stamp and a random suffix, so it
  /// cannot collide with a photo on another climb, with a second photo on this
  /// one, or with the same photo picked twice. Nothing about the source name
  /// survives except its extension, which is checked before it is used, so a
  /// file called `../../wherever.jpg` cannot smuggle a path in through the back
  /// door.
  ///
  /// Throws if the source is gone, which is the picker's temporary file being
  /// reclaimed between the pick and the copy. The caller decides what to say.
  ///
  /// The copy is capped on the way in, so a 5 MB camera photo lands as a few
  /// hundred kilobytes of the same picture. A photo already inside the cap is
  /// copied byte for byte, and so is anything the cap cannot re-encode: the
  /// user's photograph arriving intact beats the user's photograph arriving
  /// smaller.
  Future<String> copyIn(String sourcePath) async {
    // Read first, so a source that has already been reclaimed throws before
    // anything is created in the documents directory.
    final Uint8List source = await File(sourcePath).readAsBytes();
    final CappedPhoto? capped = await capPhoto(source);

    final Directory dir = await directory();
    await dir.create(recursive: true);

    final String filename = await _freeName(dir, _extensionOf(sourcePath));
    await _writeWhole(dir, filename, capped?.bytes ?? source);
    return filename;
  }

  /// Brings every photo already in the documents directory inside the cap.
  ///
  /// The one-time pass for photos taken before the cap existed. It runs over
  /// files rather than over rows, so it needs no database and no schema
  /// version: what a climb stores is a filename, each file is rewritten under
  /// the name it already has, and no row changes. A photo the cap cannot
  /// improve is left untouched rather than rewritten for the sake of it.
  ///
  /// Nothing is destroyed part way. Each rewrite is built beside the photo and
  /// only replaces it once it is whole, so a phone that dies mid-pass still has
  /// every original. Nothing is lost by running it twice either: the second run
  /// finds every photo inside the cap already.
  Future<PhotoCapReport> capStoredPhotos() async {
    final Directory dir = await directory();
    if (!await dir.exists()) return const PhotoCapReport();

    final File marker = File(_pathIn(dir, _capMarker));
    if (await _markerIsCurrent(marker)) return const PhotoCapReport();

    var report = const PhotoCapReport();
    for (final FileSystemEntity entity in await dir.list().toList()) {
      final String name = _nameOf(entity);
      if (entity is! File) continue;

      // A rewrite that a crash interrupted last time. It has no photo of its
      // own in it, so it goes rather than being scanned.
      if (name.startsWith(_workingPrefix)) {
        try {
          await entity.delete();
        } catch (_) {
          // Clutter, and no reason to stop the pass over it.
        }
        continue;
      }

      if (!name.startsWith('${_prefix}_')) continue;
      report = await _capOne(dir, entity, name, report);
    }

    try {
      await marker.writeAsString('$photoLongEdgeCap', flush: true);
    } catch (_) {
      // The pass did its work; it just cannot say so. Next launch reads every
      // photo again and finds them all inside the cap already, which costs a
      // header read each and changes nothing.
    }
    return report;
  }

  /// One photo, rewritten if the cap can improve it, counted either way.
  ///
  /// Every failure lands here and leaves the file as it was. A photo that will
  /// not decode, a disk that will not take the rewrite, a permission that
  /// changed underneath: all of them mean the user keeps the photo they had.
  Future<PhotoCapReport> _capOne(
    Directory dir,
    File file,
    String name,
    PhotoCapReport soFar,
  ) async {
    final int before = await file.length();
    try {
      final CappedPhoto? capped = await capPhoto(await file.readAsBytes());
      if (capped == null) return soFar.afterKeeping(before);

      await _writeWhole(dir, name, capped.bytes);
      return soFar.afterRewriting(before: before, after: capped.bytes.length);
    } catch (_) {
      return soFar.afterKeeping(before);
    }
  }

  /// True when this directory has already been through the cap it is on now.
  Future<bool> _markerIsCurrent(File marker) async {
    try {
      if (!await marker.exists()) return false;
      return (await marker.readAsString()).trim() == '$photoLongEdgeCap';
    } catch (_) {
      return false;
    }
  }

  /// Writes [bytes] to [filename], all of it or none of it.
  ///
  /// Built beside the target and moved onto it, because the target may be a
  /// photo the user already has. Writing in place would empty the file first,
  /// and a phone that died at that moment would have taken the photograph with
  /// it. A rename within one directory swaps the name over in one step, so the
  /// old bytes are readable until the new ones are all there.
  Future<void> _writeWhole(
    Directory dir,
    String filename,
    Uint8List bytes,
  ) async {
    final File working = File(_pathIn(dir, '$_workingPrefix$filename'));
    try {
      await working.writeAsBytes(bytes, flush: true);
      await working.rename(_pathIn(dir, filename));
    } catch (_) {
      try {
        if (await working.exists()) await working.delete();
      } catch (_) {
        // A leftover is swept up by the next pass. Losing the real error to a
        // failed tidy-up would be the worse trade.
      }
      rethrow;
    }
  }

  static String _nameOf(FileSystemEntity entity) =>
      entity.path.split(RegExp(r'[/\\]')).last;

  /// Deletes one stored photo. A file that is already gone is not an error:
  /// the end state is the same either way.
  Future<void> remove(String filename) async {
    if (!isBarePhotoFilename(filename)) return;
    final Directory dir = await directory();
    final File file = File(_pathIn(dir, filename));
    if (await file.exists()) await file.delete();
  }

  /// Deletes several, and never throws.
  ///
  /// Two reasons to swallow everything rather than the file errors alone. One
  /// failure must not take the other deletions with it. And the caller that
  /// matters most is a sheet being disposed, where an escaping error has
  /// nowhere to go and no screen left to show it: a file that would not delete
  /// is clutter, a crash on the way out of a screen is something the user sees.
  Future<void> removeAll(Iterable<String> filenames) async {
    for (final String filename in filenames) {
      try {
        await remove(filename);
      } catch (_) {
        continue;
      }
    }
  }

  /// The full path of a stored photo, resolved against the directory as it is
  /// right now.
  ///
  /// Call it at render time. Holding the answer anywhere, in memory or in the
  /// database, is the mistake this whole file exists to prevent.
  Future<String> resolve(String filename) async =>
      _pathIn(await directory(), filename);

  String _pathIn(Directory dir, String filename) =>
      '${dir.path}${Platform.pathSeparator}$filename';

  /// A name no file in [dir] is using yet.
  ///
  /// The stamp and the suffix make a collision vanishingly unlikely on their
  /// own. Checking anyway costs one `exists` per photo and turns vanishingly
  /// unlikely into cannot happen, which is the standard the rest of this file
  /// is written to.
  Future<String> _freeName(Directory dir, String extension) async {
    while (true) {
      final String candidate =
          '$_prefix'
          '_${DateTime.now().microsecondsSinceEpoch}'
          '_${_randomSuffix()}$extension';
      if (!await File(_pathIn(dir, candidate)).exists()) return candidate;
    }
  }

  static String _randomSuffix() {
    const String alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List<String>.generate(
      _suffixLength,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }

  /// The extension of [sourcePath], lowercased, or [_fallbackExtension].
  ///
  /// Whitelisted rather than trusted. This is the only part of a stored name
  /// that comes from outside, so it is only accepted when it is a dot followed
  /// by a few letters or digits. Anything else, including a name with no dot
  /// at all, gets the fallback.
  static String _extensionOf(String sourcePath) {
    final String name = sourcePath.split(RegExp(r'[/\\]')).last;
    final int dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return _fallbackExtension;

    final String extension = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(extension)
        ? extension
        : _fallbackExtension;
  }
}

/// What one run of [PhotoStore.capStoredPhotos] did.
///
/// Counted rather than logged. There is no `print` in this project and a
/// startup pass has nobody to tell anyway, so the numbers come back to the
/// caller and a test asserts on them.
class PhotoCapReport {
  const PhotoCapReport({
    this.scanned = 0,
    this.rewritten = 0,
    this.bytesBefore = 0,
    this.bytesAfter = 0,
  });

  /// Photos the pass looked at.
  final int scanned;

  /// Photos it made smaller. The rest were already inside the cap.
  final int rewritten;

  /// What the scanned photos occupied before and after, in bytes.
  final int bytesBefore;
  final int bytesAfter;

  /// This report plus a photo left exactly as it was found.
  PhotoCapReport afterKeeping(int bytes) => PhotoCapReport(
    scanned: scanned + 1,
    rewritten: rewritten,
    bytesBefore: bytesBefore + bytes,
    bytesAfter: bytesAfter + bytes,
  );

  /// This report plus a photo the cap made smaller.
  PhotoCapReport afterRewriting({required int before, required int after}) =>
      PhotoCapReport(
        scanned: scanned + 1,
        rewritten: rewritten + 1,
        bytesBefore: bytesBefore + before,
        bytesAfter: bytesAfter + after,
      );
}
