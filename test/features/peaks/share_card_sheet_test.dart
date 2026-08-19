import 'dart:async';
import 'dart:typed_data';

import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/climb_dao.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/peaks/peaks_providers.dart';
import 'package:cairn/features/peaks/share_card.dart';
import 'package:cairn/features/peaks/widgets/share_card_sheet.dart';
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

      expect(find.text(ShareCardSheet.shareFailedMessage), findsOneWidget);
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
      expect(find.text(ShareCardSheet.shareFailedMessage), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('two taps inside one frame hand the card over once', (
      tester,
    ) async {
      // The T32 bug. The button only starts ignoring presses on the frame after
      // the first tap, so both taps land on the tree that was still idle, and the
      // second one rendered the card again and put it in front of the platform a
      // second time. What the receiving end saw was the same card twice.
      final FakeShareSheet platform = FakeShareSheet();
      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();

      // No pump between the two, and that gap is the whole test.
      await tester.tap(shareButton());
      await tester.tap(shareButton());

      // Twice through on purpose. A second handover runs a moment behind the
      // first, so reading the count the instant the first one landed would find
      // one either way.
      await settleRealWork(tester);
      await settleRealWork(tester);

      expect(platform.calls, hasLength(1));
      // And nothing was said about a failure, which is what a second render
      // giving up on a boundary already being read would have put here.
      expect(find.text(ShareCardSheet.shareFailedMessage), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('the tap that was refused says nothing about a failure', (
      tester,
    ) async {
      // Why the guard is not in the controller. Refusing there means answering
      // the second call with false, and false is what a failed handover already
      // returns, so the sheet would put its failure line up over a card that is
      // on its way. The handover is held open here, so the frame that would carry
      // that lie is a frame this test can look at.
      final _ControlledShareSheet platform = _ControlledShareSheet()
        ..holdHandovers();
      // Released whatever happens, including on a failed expectation below. A
      // handover left parked never answers, and the share waiting on it would
      // resume inside whichever test ran next.
      addTearDown(platform.letEverythingThrough);

      final int id = await climbPeak('Mt. Pulag', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();

      await tester.tap(shareButton());
      await tester.tap(shareButton());
      await settleRealWork(tester);

      // All read while the handover is held, all asserted after it has been let
      // go. An expectation that failed with one still parked would leave a share
      // waiting on an answer that never comes.
      final int parkedWhileSharing = platform.parked;
      final int callsWhileSharing = platform.calls.length;
      final bool blamedTheShare = find
          .text(ShareCardSheet.shareFailedMessage)
          .evaluate()
          .isNotEmpty;
      final bool cardStillOnScreen = find
          .byType(ShareCardView)
          .evaluate()
          .isNotEmpty;

      // And the handover the first tap started still lands.
      platform.letEverythingThrough();
      await settleRealWork(tester);

      // A floor rather than a count, so the verdict on a second handover belongs
      // to the assertion below and its reason rather than to this sanity check.
      expect(
        parkedWhileSharing,
        greaterThanOrEqualTo(1),
        reason: 'nothing was being held open',
      );
      expect(
        callsWhileSharing,
        1,
        reason: 'the second tap reached the platform',
      );
      expect(
        blamedTheShare,
        isFalse,
        reason: 'the refused tap put a failure line over a share in flight',
      );
      expect(cardStillOnScreen, isTrue);
      expect(platform.calls, hasLength(1));
      expect(find.text(ShareCardSheet.shareFailedMessage), findsNothing);

      await disposeApp(tester);
    });

    testWidgets('a handover that really failed can be tapped again and lands', (
      tester,
    ) async {
      // The other half of a guard: it has to let go. One that latched would pass
      // both tests above and leave the card on screen under a button that does
      // nothing. This sheet stays open on a handover that worked as well, so the
      // guard cannot let go on the failure branch alone the way T31's does.
      final _ControlledShareSheet platform = _ControlledShareSheet()
        ..refuseNextHandover = true;
      final int id = await climbPeak('Mt. Ulap', DateTime.utc(2026, 8, 11));
      await openPeak(tester, id, platform: platform);

      await tester.tap(shareControl());
      await tester.pumpAndSettle();

      await tester.tap(shareButton());
      await settleRealWork(tester);

      expect(platform.calls, hasLength(1));
      expect(find.text(ShareCardSheet.shareFailedMessage), findsOneWidget);

      // The same button, tapped again, with the card still on the sheet.
      await tester.tap(shareButton());
      await settleRealWork(tester);

      expect(platform.calls, hasLength(2));
      expect(find.text(ShareCardSheet.shareFailedMessage), findsNothing);

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

/// The platform seam with a valve and a switch on it.
///
/// Two things [FakeShareSheet] will not do on demand: hold a handover open, so a
/// test can look at the sheet while one is in flight, and refuse one once, so a
/// test can tap again afterwards and prove the second one got through.
class _ControlledShareSheet extends FakeShareSheet {
  /// One per handover parked at the gate.
  final List<Completer<void>> _gates = <Completer<void>>[];

  bool _holding = false;

  /// The next handover throws instead of landing, once.
  bool refuseNextHandover = false;

  /// How many handovers are parked right now.
  int get parked => _gates.length;

  /// Handovers wait from here on, rather than answering.
  void holdHandovers() => _holding = true;

  /// Lets every handover answer: the ones parked now and the ones still to come.
  void letEverythingThrough() {
    _holding = false;
    final List<Completer<void>> waiting = List<Completer<void>>.of(_gates);
    _gates.clear();
    for (final Completer<void> gate in waiting) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String filename,
    required String message,
  }) async {
    // Recorded before the gate, because the count is the sharp assertion about a
    // double tap. A card can be counted a moment too early, but a handover that
    // was never made cannot turn up later.
    await super.shareImage(png: png, filename: filename, message: message);

    if (_holding) {
      final Completer<void> gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }

    if (refuseNextHandover) {
      refuseNextHandover = false;
      throw const _HandoverRefused();
    }
  }
}

/// Thrown by [_ControlledShareSheet] in place of a handover, so a refusal a test
/// asked for reads differently from one it did not.
class _HandoverRefused implements Exception {
  const _HandoverRefused();

  @override
  String toString() => 'the test refused this handover';
}
