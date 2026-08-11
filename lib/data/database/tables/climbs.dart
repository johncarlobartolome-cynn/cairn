import 'package:drift/drift.dart';

import '../converters/date_only_converter.dart';
import '../converters/photo_filenames_converter.dart';
import 'mountains.dart';

/// One logged ascent of one peak. A peak can be climbed more than once.
@DataClassName('Climb')
@TableIndex(name: 'idx_climbs_mountain_id', columns: {#mountainId})
@TableIndex(name: 'idx_climbs_date', columns: {#date})
class Climbs extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Deleting a peak takes its climbs with it.
  IntColumn get mountainId =>
      integer().references(Mountains, #id, onDelete: KeyAction.cascade)();

  /// A calendar day, not a timestamp: 11 August stays 11 August whatever the
  /// phone's timezone does. Stored as `YYYY-MM-DD` text by
  /// [DateOnlyConverter]. Required, because a climb with no date is not a climb.
  TextColumn get date => text().map(const DateOnlyConverter())();

  TextColumn get companions => text().nullable()();

  TextColumn get notes => text().nullable()();

  /// Empty list by default, so reading a photo-less climb needs no null check.
  TextColumn get photoFilenames => text()
      .map(const PhotoFilenamesConverter())
      .withDefault(const Constant('[]'))();
}
