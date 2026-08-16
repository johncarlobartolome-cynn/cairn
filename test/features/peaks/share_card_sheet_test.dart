import 'dart:typed_data';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/peaks/peaks_providers.dart';
import 'package:cairn/features/peaks/share_card.dart';
import 'package:cairn/features/peaks/widgets/share_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_share_sheet.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The whole share path, from the control on peak detail to the bytes handed to
/// the platform.
///
/// The system share sheet belongs to another process, so the last step is a
/// fake. Everything before it is Cairn's own: whether the control is there at
/// all, what the sheet shows, what the picture is, and what happens when the
/// handover fails.
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

  /// Logs one climb of [name] and hands back the peak's id.
  Future<int> climbPeak(String name, DateTime day) async {
    final Mountain peak = await peakNamed(name);
    await climbs.logClimb(mountainId: peak.id, date: day);
    return peak.id;
  }

  Future<void> openPeak(
    WidgetTester tester,
    int id, {
    FakeShareSheet? platform,
  }) async {
    await pumpApp(
      tester,
      db,
      location: CairnRoute.mountain(id),
      overrides: <Override>[
        if (platform != null) shareSheetProvider.overrideWithValue(platform),
      ],
    );
  }

  /// Lets the real event loop finish work the fake clock cannot.
  ///
  /// Rendering the card is engine work: `toImage` and `toByteData` are answered
  /// off the real event loop, so the test has to leave the fake clock and come
  /// back. Alternating is what carries a chain of awaits through, one link per
  /// round.
  Future<void> settleRealWork(WidgetTester tester) async {
    for (var round = 0; round < 8; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  Finder shareControl() => find.byIcon(Icons.share_rounded);
  Finder shareButton() => find.widgetWithText(FilledButton, 'Share');

  group('the way in', () {
    testWidgets('an unclimbed peak offers nothing to share', (tester) async {
      await openPeak(tester, (await peakNamed('Mt. Pulag')).id);

      expect(find.text('Mt. Pulag'), findsOneWidget);
      expect(shareControl(), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('a climbed peak carries the control in the bar', (
      tester,
    ) async {
      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id);

      expect(shareControl(), findsOneWidget);
      // Beside the way out, not competing with the primary action below.
      expect(find.text('Mark climbed'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('it is the app\'s only share control', (tester) async {
      // Named here so a later ticket adding a second one has to argue with a
      // test rather than with a comment. Three candidates were weighed and one
      // won; see the note on _ShareAction in peak_detail_screen.dart.
      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));

      await pumpApp(tester, db, location: CairnRoute.badges);
      expect(shareControl(), findsNothing);
      await disposeApp(tester);

      await pumpApp(tester, db, location: CairnRoute.peaks);
      expect(shareControl(), findsNothing);
      await disposeApp(tester);

      await openPeak(tester, id);
      expect(shareControl(), findsOneWidget);
      await disposeApp(tester);
    });
  });

  group('the sheet', () {
    testWidgets('shows the card that would be sent, and says so', (
      tester,
    ) async {
      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();

      expect(find.byType(ShareCardView), findsOneWidget);
      expect(find.text('Climbed 11 August 2026'), findsOneWidget);
      expect(find.text('That makes 1 of 6 peaks.'), findsOneWidget);
      expect(
        find.text(
          'Only this card leaves your phone. Your notes and photos stay here.',
        ),
        findsOneWidget,
      );
      expect(shareButton(), findsOneWidget);

      await disposeApp(tester);
    });
  });

  group('the handover', () {
    testWidgets('sends the picture, its name and one line of text', (
      tester,
    ) async {
      final FakeShareSheet platform = FakeShareSheet();
      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();
      await tester.tap(shareButton());
      await settleRealWork(tester);

      expect(platform.calls, hasLength(1));
      expect(platform.last.filename, 'cairn-mt-pulag.png');
      expect(
        platform.last.message,
        'Mt. Pulag, climbed 11 August 2026. That makes 1 of 6 peaks.',
      );

      final Uint8List png = platform.last.png;
      expect(isPng(png), isTrue, reason: 'the file has to open as an image');
      // Same width off any handset. The preview here is scaled down to fit a
      // 360dp phone and the file is not.
      expect(pngSize(png).width, (ShareCardView.width * 3).round());
      expect(pngSize(png).height, greaterThan(0));

      await disposeApp(tester);
    });

    testWidgets('a platform that refuses says so and keeps the card', (
      tester,
    ) async {
      final FakeShareSheet platform = FakeShareSheet(
        failure: StateError('no app on this phone can take a picture'),
      );
      final int id = await climbPeak('Mt. Ulap', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();
      await tester.tap(shareButton());
      await settleRealWork(tester);

      expect(
        find.text('That did not share. Give it another go.'),
        findsOneWidget,
      );
      // The sheet stays open with the card still on it, so the next tap is a
      // retry rather than a walk back through the app.
      expect(find.byType(ShareCardView), findsOneWidget);
      expect(shareButton(), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('a second try after a failure gets through', (tester) async {
      final FakeShareSheet platform = FakeShareSheet();
      final int id = await climbPeak('Mt. Ulap', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();
      await tester.tap(shareButton());
      await settleRealWork(tester);
      await tester.tap(shareButton());
      await settleRealWork(tester);

      expect(platform.calls, hasLength(2));
      expect(
        find.text('That did not share. Give it another go.'),
        findsNothing,
      );

      await disposeApp(tester);
    });
  });

  group('the controller', () {
    const ShareCard card = ShareCard(
      peakName: 'Mt. Pulag',
      climbedLine: 'Climbed 11 August 2026',
      facts: <String>['2,922 m', 'Easy'],
      tally: 'That makes 1 of 6 peaks.',
      message: 'Mt. Pulag, climbed 11 August 2026. That makes 1 of 6 peaks.',
      filename: 'cairn-mt-pulag.png',
    );

    ProviderContainer containerWith(FakeShareSheet platform) {
      final container = ProviderContainer(
        overrides: <Override>[
          databaseProvider.overrideWithValue(db),
          shareSheetProvider.overrideWithValue(platform),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a card that never painted is never handed over', () async {
      final FakeShareSheet platform = FakeShareSheet();
      final container = containerWith(platform);

      final bool shared = await container
          .read(shareCardControllerProvider.notifier)
          .share(card: card, render: () async => null);

      expect(shared, isFalse);
      expect(platform.calls, isEmpty);
      expect(container.read(shareCardControllerProvider).hasError, isTrue);
    });

    test('a render that throws fails the same way as a refusal', () async {
      final FakeShareSheet platform = FakeShareSheet();
      final container = containerWith(platform);

      final bool shared = await container
          .read(shareCardControllerProvider.notifier)
          .share(
            card: card,
            render: () async => throw StateError('the layer was gone'),
          );

      expect(shared, isFalse);
      expect(platform.calls, isEmpty);
      expect(container.read(shareCardControllerProvider).hasError, isTrue);
    });

    test('a failure does not stick to the next attempt', () async {
      final FakeShareSheet platform = FakeShareSheet();
      final container = containerWith(platform);
      final notifier = container.read(shareCardControllerProvider.notifier);

      await notifier.share(card: card, render: () async => null);
      final bool shared = await notifier.share(
        card: card,
        render: () async => Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(shared, isTrue);
      expect(container.read(shareCardControllerProvider).hasError, isFalse);
      expect(platform.last.filename, 'cairn-mt-pulag.png');
    });
  });
}
