import 'package:cairn/app/router.dart';
import 'package:cairn/data/database/daos/mountain_dao.dart';
import 'package:cairn/data/database/database.dart';
import 'package:cairn/shared/widgets/section_label.dart';
import 'package:cairn/shared/widgets/stat_tile.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/test_database.dart';

/// The longest of the six researched jump-offs, carrying a registration note on
/// top of the address. Held here rather than read out of the seed, so the test
/// keeps proving the layout even if the data changes.
const _longJumpOff =
    'Brgy. Poblacion, Bakun (register at Bakun National High School or the '
    'Municipal Tourism Council)';

void main() {
  late AppDatabase db;
  late MountainDao dao;

  setUp(() {
    db = createTestDatabase();
    dao = MountainDao(db);
  });

  tearDown(() => db.close());

  /// A peak of its own, so the fixture never collides with a seeded name and the
  /// six shipped rows stay as they are.
  Future<int> addPeak({String? jumpOffPoint}) => dao.add(
    MountainsCompanion.insert(
      name: 'Mt. Tenglawan',
      jumpOffPoint: Value(jumpOffPoint),
    ),
  );

  group('the jump-off section', () {
    testWidgets('renders a long jump-off in full, wrapped, under its label', (
      tester,
    ) async {
      final id = await addPeak(jumpOffPoint: _longJumpOff);

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsOneWidget);
      // The whole string is what the widget was handed, not a shortened one.
      expect(find.text(_longJumpOff), findsOneWidget);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(_longJumpOff),
      );
      expect(paragraph.didExceedMaxLines, isFalse);

      // The same string laid out at the same width with nothing capping it. If
      // the section were clipping lines, the painted box would be shorter than
      // this one.
      final painter = TextPainter(
        text: TextSpan(
          text: _longJumpOff,
          style: tester.widget<Text>(find.text(_longJumpOff)).style,
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: paragraph.size.width);

      expect(painter.computeLineMetrics().length, greaterThan(1));
      expect(
        paragraph.size.height,
        moreOrLessEquals(painter.height, epsilon: 0.5),
      );

      // Below the 2x2 grid, which is where the design puts it.
      expect(
        tester.getRect(find.text('JUMP-OFF POINT')).top,
        greaterThan(tester.getRect(find.byType(StatTile).last).bottom),
      );
      expect(tester.takeException(), isNull);

      await disposeApp(tester);
    });

    testWidgets('is absent entirely, label included, when the field is null', (
      tester,
    ) async {
      final id = await addPeak();

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsNothing);
      // Only the grid's label is left. An empty labelled section reads as a bug
      // rather than as a blank, so a peak with no jump-off shows nothing.
      expect(find.byType(SectionLabel), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('treats a blank jump-off the same as a missing one', (
      tester,
    ) async {
      final id = await addPeak(jumpOffPoint: '   ');

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('JUMP-OFF POINT'), findsNothing);
      expect(find.byType(SectionLabel), findsOneWidget);

      await disposeApp(tester);
    });

    testWidgets('a short jump-off gets no stat tile of its own', (
      tester,
    ) async {
      final id = await addPeak(
        jumpOffPoint: 'DENR Ambangeg Ranger Station, Bokod',
      );

      await pumpApp(tester, db, location: CairnRoute.mountain(id));

      expect(find.text('DENR Ambangeg Ranger Station, Bokod'), findsOneWidget);
      // Still the four the design names: elevation, difficulty, hours, region.
      expect(find.byType(StatTile), findsNWidgets(4));

      await disposeApp(tester);
    });
  });
}
