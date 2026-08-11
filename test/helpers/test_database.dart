import 'package:cairn/data/database/database.dart';
import 'package:drift/native.dart';

/// An [AppDatabase] on a throwaway in-memory SQLite database.
///
/// It runs the same `beforeOpen` hook as the app, so the foreign-key pragma is
/// on and the six peaks are already seeded. Close it in `tearDown`; each call
/// hands back a database that shares nothing with the last one.
AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());
