import 'package:drift/drift.dart';

/// How hard a peak is to climb.
///
/// Stored as text so the database stays readable and adding a tier later needs
/// no migration.
enum Difficulty { easy, moderate, hard }

/// A peak in the library, either curated or added by the user.
///
/// Only [name] is required. Nobody types an elevation from memory, and the
/// feature set lets a user add their own peak, so the UI shows what exists and
/// omits what does not.
@DataClassName('Mountain')
class Mountains extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Unique, so the seed can insert-or-ignore and stay idempotent.
  TextColumn get name => text().unique()();

  TextColumn get region => text().nullable()();

  IntColumn get elevationM => integer().nullable()();

  TextColumn get difficulty => textEnum<Difficulty>().nullable()();

  TextColumn get jumpOffPoint => text().nullable()();

  /// Hours, not minutes, and fractional: a peak can be a 3.5 hour walk.
  RealColumn get estimatedHours => real().nullable()();

  TextColumn get notes => text().nullable()();
}
