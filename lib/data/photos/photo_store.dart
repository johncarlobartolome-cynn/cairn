import 'dart:io';
import 'dart:math';

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
  Future<String> copyIn(String sourcePath) async {
    final Directory dir = await directory();
    await dir.create(recursive: true);

    final String filename = await _freeName(dir, _extensionOf(sourcePath));
    await File(sourcePath).copy(_pathIn(dir, filename));
    return filename;
  }

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
