import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/climbs_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// The write path itself, with no widget in the way.
///
/// Everything the app writes goes through [MarkClimbedController], so this is
/// where the shape of a saved row is pinned down.
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = createTestDatabase();
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  MarkClimbedController controller() =>
      container.read(markClimbedControllerProvider.notifier);

  Future<int> pulagId() async =>
      (await container.read(mountainDaoProvider).getAll())
          .firstWhere((p) => p.name == 'Mt. Pulag')
          .id;

  Future<List<Climb>> storedClimbs() =>
      container.read(climbDaoProvider).watchAll().first;

  test('saves the day, the companions and the notes', () async {
    final id = await pulagId();

    final saved = await controller().save(
      mountainId: id,
      date: DateTime(2026, 8, 11, 16, 20),
      companions: 'Mara and Enzo',
      notes: 'Sea of clouds at sunrise.',
    );

    expect(saved, isNotNull);

    final climb = (await storedClimbs()).single;
    expect(climb.id, saved!.id);
    expect(climb.mountainId, id);
    // The calendar day, with the afternoon it was typed in dropped on the way.
    expect(climb.date, DateTime.utc(2026, 8, 11));
    expect(climb.companions, 'Mara and Enzo');
    expect(climb.notes, 'Sea of clouds at sunrise.');
    // T17's column, still empty and still readable without a null check.
    expect(climb.photoFilenames, isEmpty);
  });

  test('an untouched optional field stores as nothing at all', () async {
    final saved = await controller().save(
      mountainId: await pulagId(),
      date: DateTime(2026, 8, 11),
    );

    expect(saved, isNotNull);

    final climb = (await storedClimbs()).single;
    expect(climb.companions, isNull);
    expect(climb.notes, isNull);
  });

  test('a field holding only spaces stores as nothing either', () async {
    // A text field someone tabbed through and a text field someone typed two
    // spaces into are the same answer, and both must read back as absent rather
    // than as a blank line under a heading.
    await controller().save(
      mountainId: await pulagId(),
      date: DateTime(2026, 8, 11),
      companions: '   ',
      notes: '\n  \n',
    );

    final climb = (await storedClimbs()).single;
    expect(climb.companions, isNull);
    expect(climb.notes, isNull);
  });

  test('what was typed is trimmed, not stored with its edges', () async {
    await controller().save(
      mountainId: await pulagId(),
      date: DateTime(2026, 8, 11),
      companions: '  Mara  ',
    );

    expect((await storedClimbs()).single.companions, 'Mara');
  });

  test(
    'the same peak on the same day saves twice, no duplicate check',
    () async {
      // A peak can be climbed as often as you like, and twice in one day is a
      // real answer. Nothing about a climb is unique.
      final id = await pulagId();
      final day = DateTime(2026, 8, 11);

      final first = await controller().save(mountainId: id, date: day);
      final second = await controller().save(mountainId: id, date: day);

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.id, isNot(second!.id));
      expect(await storedClimbs(), hasLength(2));
    },
  );

  test(
    'the climbs stream carries the new row with nothing asking it to',
    () async {
      // The read side is a Drift watch(), so a screen showing climbs updates off
      // the insert itself. Nothing in this test refreshes or invalidates
      // anything, which is the assertion.
      final seen = <List<Climb>>[];
      final sub = container.listen<AsyncValue<List<Climb>>>(climbsProvider, (
        _,
        next,
      ) {
        final rows = next.value;
        if (rows != null) seen.add(rows);
      }, fireImmediately: true);
      addTearDown(sub.close);

      await pumpEventQueue();
      expect(seen.last, isEmpty, reason: 'the log starts empty');

      await controller().save(
        mountainId: await pulagId(),
        date: DateTime(2026, 8, 11),
        notes: 'Sea of clouds at sunrise.',
      );
      await pumpEventQueue();

      expect(seen.last, hasLength(1));
      expect(seen.last.single.notes, 'Sea of clouds at sunrise.');
    },
  );

  test('the ids of climbed peaks arrive on their own stream too', () async {
    // What T16 hangs the desaturated-to-colour flip off. Proven here so that
    // ticket starts from a stream already known to fire.
    final id = await pulagId();
    final ids = <Set<int>>[];
    final sub = container.listen<AsyncValue<Set<int>>>(
      climbedMountainIdsProvider,
      (_, next) {
        final value = next.value;
        if (value != null) ids.add(value);
      },
      fireImmediately: true,
    );
    addTearDown(sub.close);

    await pumpEventQueue();
    expect(ids.last, isEmpty);

    await controller().save(mountainId: id, date: DateTime(2026, 8, 11));
    await pumpEventQueue();

    expect(ids.last, {id});
  });

  test('a save carries back the badges it unlocked', () async {
    // What the acknowledgement is built from. The controller is the only place
    // the widget layer can learn this, and it has to be the badges that fired
    // rather than the badges the climber holds.
    final id = await pulagId();

    final first = await controller().save(
      mountainId: id,
      date: DateTime(2026, 8, 11),
    );

    expect(first!.earned.peak, isTrue, reason: 'the peak was climbed anew');
    expect(first.earned.milestones, <AchievementType>[
      AchievementType.firstClimb,
    ]);
    expect(first.earned.count, 2);

    // The same peak again earns nothing, and has to say so. A second sentence
    // naming two badges would be a lie the first one paid for.
    final second = await controller().save(
      mountainId: id,
      date: DateTime(2026, 8, 12),
    );

    expect(second!.earned.isEmpty, isTrue);
    expect(second.earned.count, 0);
  });

  test('reports it is working while the row is on its way', () async {
    final pending = controller().save(
      mountainId: await pulagId(),
      date: DateTime(2026, 8, 11),
    );

    expect(container.read(markClimbedControllerProvider).isLoading, isTrue);

    await pending;

    expect(container.read(markClimbedControllerProvider).isLoading, isFalse);
    expect(container.read(markClimbedControllerProvider).hasError, isFalse);
  });

  test('a climb against a peak that is not there comes back empty', () async {
    // The foreign key is on, so this is refused by SQLite. The controller has
    // to hand the failure back rather than let it escape into a widget
    // callback, which is what keeps the sheet open with the typing still in it.
    final saved = await controller().save(
      mountainId: 9999,
      date: DateTime(2026, 8, 11),
    );

    expect(saved, isNull);
    expect(container.read(markClimbedControllerProvider).hasError, isTrue);
    expect(await storedClimbs(), isEmpty);
  });
}
