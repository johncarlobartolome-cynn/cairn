import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The layer rule, enforced instead of trusted.
///
/// `UI → provider → DAO → table`, one direction only. The architecture note has
/// always said a widget must never call a DAO, and until now nothing stopped
/// one: T8's review found that `data/providers.dart` exports `climbDaoProvider`
/// publicly, and a DAO is not `database.dart`, so the rule as written let a
/// widget write straight into one. E3 is the first epic that could.
///
/// So the rule is a test. Any file in the widget layer that names a DAO or
/// reaches into `data/database/` fails this, with the file named.
///
/// Provider files are the exception, because talking to a DAO is the whole job
/// of one. They are the seam, and they are where a reviewer should look.
void main() {
  /// Everything above the data layer.
  const roots = <String>['lib/app', 'lib/features', 'lib/shared', 'lib/dev'];

  /// The seam. A file named this way is allowed to hold a DAO.
  const providerSuffix = '_providers.dart';

  test('no widget reaches past a provider into the data layer', () {
    final offences = <String>[];
    var scanned = 0;

    for (final root in roots) {
      final dir = Directory(root);
      expect(
        dir.existsSync(),
        isTrue,
        reason: '$root is gone, so this test is scanning nothing',
      );

      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File) continue;
        if (!entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith(providerSuffix)) continue;

        scanned++;
        final source = entity.readAsStringSync();

        if (source.contains('data/database/')) {
          offences.add(
            '${entity.path} imports data/database/ directly. Watch a provider '
            'from data/providers.dart instead.',
          );
        }
        if (source.contains('Dao')) {
          offences.add(
            '${entity.path} names a DAO. Writes go through a Notifier, reads '
            'through a StreamProvider; neither lives in a widget.',
          );
        }
      }
    }

    // A path typo would otherwise pass silently with nothing read.
    expect(scanned, greaterThan(10), reason: 'too few files read to mean much');
    expect(offences, isEmpty, reason: offences.join('\n'));
  });
}
