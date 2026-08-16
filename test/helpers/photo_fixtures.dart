import 'dart:io';

import 'package:cairn/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A throwaway directory that stands in for the app documents directory, gone
/// again when the test ends.
///
/// Two of them is how a test moves the documents directory out from under a
/// stored filename, which is the whole point of the filename-only rule.
Directory createTempDirectory(String label) {
  final Directory directory = Directory.systemTemp.createTempSync(
    'cairn_${label}_',
  );
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return directory;
}

/// Points the app's documents directory at [directory].
Override documentsDirectoryOverride(Directory directory) =>
    documentsDirectoryProvider.overrideWith((ref) async => directory);

/// Pumps on the real clock until the disk has caught up.
///
/// Anything photo-shaped is file work: looking the documents directory up,
/// copying a picked file in, deleting one on the way out, and the image loader
/// reading bytes off disk. A widget test runs on a fake clock that will not
/// advance any of it, so `pumpAndSettle` waits out its timeout and an
/// `errorBuilder` never fires.
///
/// [rounds] is generous on purpose. Each round lets one `await` in the chain
/// resume, and copying two photos is a dozen of them.
Future<void> pumpRealAsync(WidgetTester tester, {int rounds = 24}) async {
  await tester.runAsync(() async {
    for (var i = 0; i < rounds; i++) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pump();
}

/// A file where the system picker would have left one.
///
/// The bytes are not an image and nothing here needs them to be. Every host
/// test asserts on the path a widget resolved or on the name that reached the
/// database, and the one test that wants a decode to fail wants exactly this.
/// A photograph that really decodes is what the device run is for.
File writePickedFile(Directory directory, String name) {
  final File file = File('${directory.path}${Platform.pathSeparator}$name');
  file.writeAsBytesSync(List<int>.filled(64, 7));
  return file;
}

/// The system picker, stood in for.
///
/// The real one is another process and no test can tap it. Everything after the
/// pick is Cairn's own work, so the seam is where the proving starts.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.paths = const <String>[]]);

  /// What the next [pick] hands back. Assign to change the answer mid-test.
  List<String> paths;

  /// How many times the sheet opened the picker.
  int openings = 0;

  /// Thrown instead of answering, for the copy-failed path.
  Object? failure;

  @override
  Future<List<String>> pick() async {
    openings++;
    final Object? thrown = failure;
    if (thrown != null) throw thrown;
    return paths;
  }
}
