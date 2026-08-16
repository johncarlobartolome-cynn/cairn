import 'dart:convert';

import 'package:drift/drift.dart';

import '../../photos/photo_filename.dart';

/// Stores climb photos as a JSON list of bare filenames.
///
/// Filenames only, never absolute paths. The app container directory changes
/// between installs, so a stored path resolves to nothing after a reinstall.
/// Callers resolve each filename against the documents directory at render time.
///
/// [toSql] enforces that instead of asking for it. Every write to the column
/// goes through this one method, so a path arriving from anywhere fails loudly
/// at save time rather than quietly the day the app is reinstalled. The failure
/// is the point: a refused save is a bug someone fixes, and a saved path is a
/// photo nobody can find and nobody knows to look for.
class PhotoFilenamesConverter extends TypeConverter<List<String>, String> {
  const PhotoFilenamesConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    return (jsonDecode(fromDb) as List<dynamic>).cast<String>();
  }

  @override
  String toSql(List<String> value) {
    for (final String filename in value) {
      if (!isBarePhotoFilename(filename)) {
        throw ArgumentError.value(
          filename,
          'photoFilenames',
          'A climb photo is stored as a bare filename. Anything carrying a '
              'directory resolves to nothing once the app container moves, '
              'and nothing reports it. Copy the file into the documents '
              'directory with PhotoStore and store what it hands back.',
        );
      }
    }
    return jsonEncode(value);
  }
}
