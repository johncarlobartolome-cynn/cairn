import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// The app's write path for climbs. Nothing else inserts a row.
///
/// The layer rule is `UI → provider → DAO → table`, and the architecture note
/// has always said a widget must never call a DAO. Nothing enforced it: T8's
/// review found that `data/providers.dart` exports `climbDaoProvider` publicly,
/// and this epic is the first that could walk through that hole. So the sheet
/// calls [MarkClimbedController.save] and `test/architecture/layer_rule_test.dart`
/// keeps the widget layer honest.
///
/// Not auto-disposed. The sheet can be swiped away while a save is in flight,
/// and a controller that disposed underneath its own await would throw on the
/// way back. Living for the app's lifetime costs one object and removes that
/// race entirely.
final markClimbedControllerProvider =
    AsyncNotifierProvider<MarkClimbedController, void>(
      MarkClimbedController.new,
    );

/// Logs a climb against a peak.
///
/// [AsyncNotifier] rather than a plain [Notifier] because the write is a
/// database round trip: the state carries loading and error, which is what lets
/// the sheet show a busy button and refuse a second tap.
///
/// It holds no result. Reads are Drift `watch()` streams, so a screen showing
/// climbs updates itself off the insert with no invalidation and nothing to
/// hand back here.
class MarkClimbedController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Writes one climb and returns its new row id, or null when the write
  /// failed.
  ///
  /// [date] is a calendar day. The caller passes the day the user picked and
  /// the column's converter drops anything below it, so the clock time riding
  /// along on a `DateTime` never reaches the file.
  ///
  /// [companions] and [notes] are optional. Blank is the same as absent, so a
  /// field the user tabbed through stores as null rather than as an empty
  /// string that later renders as an empty line.
  Future<int?> save({
    required int mountainId,
    required DateTime date,
    String? companions,
    String? notes,
  }) async {
    state = const AsyncValue<void>.loading();
    try {
      final id = await ref
          .read(climbDaoProvider)
          .logClimb(
            mountainId: mountainId,
            date: date,
            companions: _filled(companions),
            notes: _filled(notes),
          );
      state = const AsyncValue<void>.data(null);
      return id;
    } catch (error, stackTrace) {
      state = AsyncValue<void>.error(error, stackTrace);
      return null;
    }
  }
}

/// The text of a field someone actually filled in, or null.
String? _filled(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
