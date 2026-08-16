import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/features/peaks/share_card.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_database.dart';

/// What the shared card says, before anything paints it.
///
/// This is the one thing in the app that ends up on somebody else's phone with
/// no app around it to explain it, so every fact on it is held here rather than
/// left to a screenshot to catch.
///
/// Rows come from a real database and the real DAOs, so the card is built from
/// the shapes the app actually hands it.
void main() {
  late AppDatabase db;
  late MountainDao mountains;
  late ClimbDao climbs;

  setUp(() {
    db = createTestDatabase();
    mountains = MountainDao(db);
    climbs = ClimbDao(db);
  });

  tearDown(() => db.close());

  Future<Mountain> peakNamed(String name) async =>
      (await mountains.getAll()).firstWhere((peak) => peak.name == name);

  Future<ShareCard?> cardFor(String name) async => ShareCard.from(
    peak: await peakNamed(name),
    climbs: await climbs.getAll(),
    libraryTotal: (await mountains.getAll()).length,
  );

  group('whether there is anything to share', () {
    test('an unclimbed peak has no card', () async {
      expect(await cardFor('Mt. Pulag'), isNull);
    });

    test('one climb is enough', () async {
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Pulag')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      expect(await cardFor('Mt. Pulag'), isNotNull);
      // And only for the peak that was climbed.
      expect(await cardFor('Mt. Ulap'), isNull);
    });
  });

  group('what it says', () {
    test('the peak, the day, the facts and the tally', () async {
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Pulag')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      final ShareCard card = (await cardFor('Mt. Pulag'))!;

      expect(card.peakName, 'Mt. Pulag');
      expect(card.climbedLine, 'Climbed 11 August 2026');
      expect(card.facts, <String>['2,922 m', 'Easy']);
      expect(card.tally, 'That makes 1 of 6 peaks.');
    });

    test('the day is the day of the climb, not the day it was logged', () async {
      // The badge row would say today, because a badge fires when a climb is
      // saved. A hike from 2019 logged this evening is still a hike from 2019,
      // and this card is the most public thing the app writes.
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Ulap')).id,
        date: DateTime.utc(2019, 3, 4),
        unlockedAt: DateTime.utc(2026, 8, 17, 21, 30),
      );

      expect((await cardFor('Mt. Ulap'))!.climbedLine, 'Climbed 4 March 2019');
    });

    test('a peak with no facts recorded drops the row', () async {
      await mountains.add(MountainsCompanion.insert(name: 'Mt. Namelessdata'));
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Namelessdata')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      final ShareCard card = (await cardFor('Mt. Namelessdata'))!;
      expect(card.facts, isEmpty);
      // The rest of the card still stands on its own.
      expect(card.peakName, 'Mt. Namelessdata');
      expect(card.climbedLine, 'Climbed 11 August 2026');
    });

    test('one fact on its own still shows', () async {
      await mountains.add(
        MountainsCompanion.insert(
          name: 'Mt. Halcon',
          elevationM: const Value(2586),
        ),
      );
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Halcon')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      expect((await cardFor('Mt. Halcon'))!.facts, <String>['2,586 m']);
    });

    test('the message says what the picture says', () async {
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Pulag')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      final ShareCard card = (await cardFor('Mt. Pulag'))!;
      expect(
        card.message,
        'Mt. Pulag, climbed 11 August 2026. That makes 1 of 6 peaks.',
      );
      // It stands alone in a chat with no picture beside it, so it names no
      // app and asks for nothing.
      expect(card.message.toLowerCase(), isNot(contains('cairn')));
      expect(card.message, isNot(contains('http')));
    });
  });

  group('the tally', () {
    Future<void> climb(String name, DateTime day) async =>
        climbs.logClimb(mountainId: (await peakNamed(name)).id, date: day);

    test('counts in the order the peaks were climbed', () async {
      // Deliberately not alphabetical, and not the library's order either.
      await climb('Mt. Ulap', DateTime.utc(2026, 1, 5));
      await climb('Mt. Batulao', DateTime.utc(2026, 3, 9));
      await climb('Mt. Pulag', DateTime.utc(2026, 8, 11));

      expect((await cardFor('Mt. Ulap'))!.tally, 'That makes 1 of 6 peaks.');
      expect((await cardFor('Mt. Batulao'))!.tally, 'That makes 2 of 6 peaks.');
      expect((await cardFor('Mt. Pulag'))!.tally, 'That makes 3 of 6 peaks.');
    });

    test('is counted as of that climb, not as of today', () async {
      // The whole reason it is a sentence and not a labelled number. Share the
      // first peak after climbing three and the card still says one.
      await climb('Mt. Ulap', DateTime.utc(2026, 1, 5));
      await climb('Mt. Batulao', DateTime.utc(2026, 3, 9));
      await climb('Mt. Pulag', DateTime.utc(2026, 8, 11));

      expect((await cardFor('Mt. Ulap'))!.tally, 'That makes 1 of 6 peaks.');
    });

    test('two peaks climbed on one day still get an ordinal each', () async {
      await climb('Mt. Ulap', DateTime.utc(2026, 8, 11));
      await climb('Mt. Batulao', DateTime.utc(2026, 8, 11));

      expect((await cardFor('Mt. Ulap'))!.tally, 'That makes 1 of 6 peaks.');
      expect((await cardFor('Mt. Batulao'))!.tally, 'That makes 2 of 6 peaks.');
    });

    test(
      'climbing the same peak again moves neither the day nor the number',
      () async {
        await climb('Mt. Ulap', DateTime.utc(2026, 1, 5));
        await climb('Mt. Batulao', DateTime.utc(2026, 3, 9));
        // Back up Ulap, months later. It joined the collection in January and it
        // is still the first peak.
        await climb('Mt. Ulap', DateTime.utc(2026, 9, 2));

        final ShareCard card = (await cardFor('Mt. Ulap'))!;
        expect(card.climbedLine, 'Climbed 5 January 2026');
        expect(card.tally, 'That makes 1 of 6 peaks.');
      },
    );

    test('the total follows the library rather than a fixed six', () async {
      await mountains.add(MountainsCompanion.insert(name: 'Mt. Apo'));
      await climb('Mt. Pulag', DateTime.utc(2026, 8, 11));

      expect((await cardFor('Mt. Pulag'))!.tally, 'That makes 1 of 7 peaks.');
    });

    test('never reads more climbed than the library holds', () async {
      await climb('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await climb('Mt. Ulap', DateTime.utc(2026, 8, 12));

      final ShareCard card = ShareCard.from(
        peak: await peakNamed('Mt. Ulap'),
        climbs: await climbs.getAll(),
        // A denominator that cannot be right. "2 of 1" is the failure this
        // guards, and it is the same guard the peaks progress strip carries.
        libraryTotal: 1,
      )!;

      expect(card.tally, 'That makes 2 of 2 peaks.');
    });
  });

  group('the filename', () {
    /// Adds a peak the library does not already hold, climbs it, and hands back
    /// what the receiving app would see the file called.
    Future<String> filenameForAdded(String name) async {
      await mountains.add(MountainsCompanion.insert(name: name));
      await climbs.logClimb(
        mountainId: (await peakNamed(name)).id,
        date: DateTime.utc(2026, 8, 11),
      );
      return (await cardFor(name))!.filename;
    }

    test('is the peak, kebab-cased, under the app name', () async {
      await climbs.logClimb(
        mountainId: (await peakNamed('Mt. Pulag')).id,
        date: DateTime.utc(2026, 8, 11),
      );

      expect((await cardFor('Mt. Pulag'))!.filename, 'cairn-mt-pulag.png');
    });

    test('a name a user typed cannot smuggle a path into it', () async {
      // Same rule as a stored photo's extension: whitelist, never clean.
      final String filename = await filenameForAdded('../../etc/Mt Sharp!!');

      expect(filename, 'cairn-etc-mt-sharp.png');
      expect(filename, isNot(contains('/')));
      expect(filename, isNot(contains('..')));
    });

    test('a name with nothing to slug still names a file', () async {
      expect(await filenameForAdded('###'), 'cairn-peak.png');
    });
  });

  test('every string on the card is written for the spoken voice', () async {
    await climbs.logClimb(
      mountainId: (await peakNamed('Mt. Kabunian')).id,
      date: DateTime.utc(2026, 8, 11),
    );

    final ShareCard card = (await cardFor('Mt. Kabunian'))!;
    final List<String> strings = <String>[
      card.peakName,
      card.climbedLine,
      ...card.facts,
      card.tally,
      card.message,
    ];

    for (final String line in strings) {
      expect(line, isNot(contains('—')), reason: line);
      expect(line, isNot(contains('/')), reason: line);
      expect(line, isNot(contains('(')), reason: line);
      // Ellipsis is a bug here more than anywhere else in the app.
      expect(line, isNot(contains('…')), reason: line);
      expect(line, isNot(contains('...')), reason: line);
    }
  });
}
