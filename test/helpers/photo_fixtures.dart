import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cairn/data/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

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

/// Waits on the real clock until [ready] says the work is done.
///
/// For a test with no widget in it. How long a copy takes depends on what else
/// the machine is doing, so a fixed number of turns through the event queue is a
/// race the suite loses on the day it is busiest. Waiting for the answer costs
/// nothing when it arrives quickly and does not lie when it does not.
Future<void> waitUntil(
  FutureOr<bool> Function() ready, {
  required String waitingFor,
  int giveUpAfter = 400,
}) async {
  for (var round = 0; round < giveUpAfter; round++) {
    if (await ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('gave up waiting for $waitingFor');
}

/// Pumps on the real clock until [ready] says the work is done.
///
/// One copy is half a dozen trips to the disk, so a fixed number of rounds is a
/// guess that goes stale the moment a test picks one more photo. This waits for
/// the thing the test is about instead, and gives up rather than hanging so a
/// fix that never lands fails with a sentence rather than a timeout.
///
/// [ready] may be asynchronous, which is what lets a test wait on the row
/// reaching the database rather than on a widget going away.
Future<void> pumpRealUntil(
  WidgetTester tester,
  FutureOr<bool> Function() ready, {
  required String waitingFor,
  int giveUpAfter = 200,
}) async {
  // Pumped before it is asked, always. A state change made by the tap that came
  // just before this is not on screen until a frame has run, so a first check
  // ahead of the first pump would read the tree as it was.
  for (var round = 0; round < giveUpAfter; round++) {
    await pumpRealAsync(tester, rounds: 2);
    if (await ready()) {
      // One more frame before handing back. The turn that satisfied the
      // condition is usually the turn that changed the state as well, and the
      // frame carrying it has not been built yet.
      await pumpRealAsync(tester, rounds: 1);
      return;
    }
  }
  fail('gave up waiting for $waitingFor');
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

/// A photograph, at whatever size the test needs one.
///
/// Real image bytes rather than the stand-in above, because the cap decodes
/// what it is given and a test about pixels has to hand it some. The picture is
/// a corner mark on a plain ground: one red block in the top left, so a test
/// can say which way up the result came out, and enough noise everywhere else
/// that JPEG cannot compress it away to nothing.
///
/// [orientation] writes the EXIF tag a phone held sideways writes, and writes a
/// real one: the pixels stay the way they are given and the tag says which way
/// up to show them, which is exactly what comes off a camera. 1 is upright, and
/// 6 is the common one, the phone turned a quarter turn.
Uint8List photographBytes({
  required int width,
  required int height,
  int orientation = 1,
  bool png = false,
}) {
  final img.Image image = img.Image(width: width, height: height);

  // Deterministic noise. A flat fill would encode to a few hundred bytes and a
  // size comparison against it would prove nothing about a photograph.
  var seed = 1;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      final int n = seed >> 16 & 0x3f;
      image.setPixelRgb(x, y, 40 + n, 90 + n, 150 + n);
    }
  }

  final int markWidth = width ~/ 4;
  final int markHeight = height ~/ 4;
  for (int y = 0; y < markHeight; y++) {
    for (int x = 0; x < markWidth; x++) {
      image.setPixelRgb(x, y, 220, 30, 30);
    }
  }

  if (orientation != 1) image.exif.imageIfd.orientation = orientation;

  return png ? img.encodePng(image) : img.encodeJpg(image, quality: 95);
}

/// The size a decoder reads out of [bytes] without unpacking the picture.
///
/// The header carries the pixels as they are stored, before any EXIF tag has
/// been applied. Comparing it against the size the same bytes decode to is how
/// a test tells an upright photo from one carrying an instruction to turn.
String storedSizeOf(Uint8List bytes) {
  final img.DecodeInfo info = img
      .findDecoderForData(bytes)!
      .startDecode(bytes)!;
  return '${info.width}x${info.height}';
}

/// True when the pixel at [x], [y] is the red corner mark rather than the
/// ground it sits on.
bool isCornerMark(img.Image image, int x, int y) {
  final img.Pixel pixel = image.getPixel(x, y);
  return pixel.r > 150 && pixel.g < 100 && pixel.b < 100;
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

/// A [PhotoStore] whose copies land when the test says so.
///
/// A copy is over in a millisecond, and the window it is open in is the one the
/// sheet used to get wrong, so a test cannot hope to catch it by racing. It
/// holds the copy still instead: [holdCopies] parks every copy from then on,
/// [letOneThrough] lets exactly one land, and the test looks at the sheet in
/// between.
///
/// Open by default, so a store built here and never held behaves like the real
/// one.
class HeldPhotoStore extends PhotoStore {
  HeldPhotoStore(Directory documents)
    : super(directory: (() async => documents));

  /// One per copy waiting to be let through, oldest first.
  final List<Completer<void>> _waiting = <Completer<void>>[];

  bool _holding = false;

  /// Copies wait from here on, rather than going straight to disk.
  void holdCopies() => _holding = true;

  /// How many copies are parked right now.
  ///
  /// The draft copies one file at a time, so this is 1 while a pick is running
  /// and 0 between picks. A test asserts on it to say the copy really had not
  /// finished yet, rather than assuming.
  int get waiting => _waiting.length;

  /// Lets the copy that is waiting land, and leaves the rest parked.
  void letOneThrough() {
    if (_waiting.isEmpty) return;
    _waiting.removeAt(0).complete();
  }

  /// Lets every copy land: the ones parked now and the ones still to come.
  void letEverythingThrough() {
    _holding = false;
    final List<Completer<void>> parked = List<Completer<void>>.of(_waiting);
    _waiting.clear();
    for (final Completer<void> gate in parked) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<String> copyIn(String sourcePath) async {
    if (_holding) {
      final Completer<void> gate = Completer<void>();
      _waiting.add(gate);
      await gate.future;
    }
    return super.copyIn(sourcePath);
  }
}

/// Points the photo store at [store], so a test controls when copies land.
Override photoStoreOverride(PhotoStore store) =>
    photoStoreProvider.overrideWithValue(store);
