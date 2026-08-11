import 'dart:convert';

import 'package:drift/drift.dart';

import 'mountains.dart';

/// Stores climb photos as a JSON list of bare filenames.
///
/// Filenames only, never absolute paths. The app container directory changes
/// between installs, so a stored path resolves to nothing after a reinstall.
/// Callers resolve each filename against the documents directory at render
/// time.
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

/// One logged ascent of one peak. A peak can be climbed more than once.
@DataClassName('Climb')
@TableIndex(name: 'idx_climbs_mountain_id', columns: {#mountainId})
@TableIndex(name: 'idx_climbs_date', columns: {#date})
class Climbs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Deleting a peak takes its climbs with it.
  IntColumn get mountainId =>
      integer().references(Mountains, #id, onDelete: KeyAction.cascade)();

  /// Required: a climb with no date is not a climb.
  DateTimeColumn get date => dateTime()();

  TextColumn get companions => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Empty list by default, so reading a photo-less climb needs no null check.
  TextColumn get photoFilenames => text()
      .map(const PhotoFilenamesConverter())
      .withDefault(const Constant('[]'))();
}
