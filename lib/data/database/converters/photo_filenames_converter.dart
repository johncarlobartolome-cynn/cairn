import 'dart:convert';

import 'package:drift/drift.dart';

/// Stores climb photos as a JSON list of bare filenames.
///
/// Filenames only, never absolute paths. The app container directory changes
/// between installs, so a stored path resolves to nothing after a reinstall.
/// Callers resolve each filename against the documents directory at render time.
class PhotoFilenamesConverter extends TypeConverter<List<String>, String> {
  const PhotoFilenamesConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    return (jsonDecode(fromDb) as List<dynamic>).cast<String>();
  }

  @override
  String toSql(List<String> value) => jsonEncode(value);
}
