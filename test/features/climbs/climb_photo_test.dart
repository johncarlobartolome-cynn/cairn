import 'dart:io';

import 'package:cairn/app/theme/theme.dart';
import 'package:cairn/data/providers.dart';
import 'package:cairn/features/climbs/widgets/climb_photo.dart';
import 'package:cairn/features/climbs/widgets/missing_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/photo_fixtures.dart';

/// The rendering half of the photo rule.
///
/// Two properties, and they are the ones that decide whether a photo taken this
/// year is still on screen next year:
///
/// 1. The documents directory is resolved when the widget builds, so a stored
///    filename outlives the directory moving underneath it
/// 2. A file that has gone missing draws a placeholder instead of taking the
///    screen down with it
void main() {
  /// The stored value. One string, in one place, for the whole file, because
  /// the point of every test here is that this never has to change.
  const String filename = 'climb_1755300000000001_a1b2c3d4.jpg';

  /// Pumps [child] against a documents directory that [directory] answers for.
  ///
  /// The function is read on every build of the provider, so a test can move
  /// the directory and invalidate, and the same widget resolves somewhere else
  /// without being rebuilt from scratch.
  Future<ProviderContainer> pumpPhoto(
    WidgetTester tester,
    Directory Function() directory, {
    double width = 300,
    double height = 225,
  }) async {
    final container = ProviderContainer(
      overrides: <Override>[
        documentsDirectoryProvider.overrideWith((ref) async => directory()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: CairnTheme.light,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: height,
                child: const ClimbPhoto(filename: filename),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpRealAsync(tester);
    return container;
  }

  /// The path the widget resolved, read off the image it built.
  String resolvedPath(WidgetTester tester) {
    final Image image = tester.widget<Image>(find.byType(Image));
    return (image.image as FileImage).file.path;
  }

  testWidgets('resolves the stored filename against the directory it is given', (
    tester,
  ) async {
    final Directory documents = createTempDirectory('documents');
    writePickedFile(documents, filename);

    await pumpPhoto(tester, () => documents);

    expect(
      resolvedPath(tester),
      '${documents.path}${Platform.pathSeparator}$filename',
    );
  });

  testWidgets('the same stored value still renders after the directory moves', (
    tester,
  ) async {
    // A reinstall, in the one shape a host test can stage honestly: the files
    // stay, the directory around them is somewhere else, and the database is
    // never touched. Nothing below writes to the database, and the filename
    // constant above is the only thing the widget is ever given.
    final Directory before = createTempDirectory('before');
    writePickedFile(before, filename);

    Directory documents = before;
    final container = await pumpPhoto(tester, () => documents);

    final String pathBefore = resolvedPath(tester);
    expect(pathBefore, startsWith(before.path));

    // The app container is somewhere else now, with the same files inside it.
    final Directory after = Directory(
      '${before.parent.path}${Platform.pathSeparator}'
      'cairn_after_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() {
      if (after.existsSync()) after.deleteSync(recursive: true);
    });
    before.renameSync(after.path);
    documents = after;

    container.invalidate(documentsDirectoryProvider);
    await pumpRealAsync(tester);

    final String pathAfter = resolvedPath(tester);
    expect(pathAfter, startsWith(after.path));
    expect(pathAfter, isNot(pathBefore));
    expect(pathAfter.endsWith(filename), isTrue);
    expect(File(pathAfter).existsSync(), isTrue);
  });

  testWidgets('a file that is not there draws a placeholder, not an exception', (
    tester,
  ) async {
    final Directory documents = createTempDirectory('documents');

    await pumpPhoto(tester, () => documents);

    expect(find.byType(MissingPhoto), findsOneWidget);
    expect(find.text(MissingPhoto.message), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a file that is there but is not an image degrades the same way', (
    tester,
  ) async {
    // The other half of missing: the file is present and the decode fails.
    // Same errorBuilder, same placeholder, still no crash.
    final Directory documents = createTempDirectory('documents');
    writePickedFile(documents, filename);

    await pumpPhoto(tester, () => documents);

    expect(find.byType(MissingPhoto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says nothing in words when it is too small for the sentence', (
    tester,
  ) async {
    // A thumbnail on the sheet. The sentence is dropped rather than shortened,
    // because the design bans an ellipsis outright.
    final Directory documents = createTempDirectory('documents');

    await pumpPhoto(tester, () => documents, width: 96, height: 96);

    expect(find.byType(MissingPhoto), findsOneWidget);
    expect(find.text(MissingPhoto.message), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
