// The host half of the screenshot harness: `flutter drive` runs this next to the
// device, and it writes every image the test captures to disk.
//
// Run it through tool/screenshots.sh rather than by hand.

// A CLI, so printing is the interface.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Where the PNGs land, absolute or relative to the project root.
///
/// tool/screenshots.sh sets this. The fallback keeps a bare `flutter drive` from
/// scattering files somewhere surprising.
String get _outputDir =>
    Platform.environment['CAIRN_SCREENSHOT_DIR'] ?? 'screenshots';

Future<void> main() async {
  await integrationDriver(
    onScreenshot:
        (String name, List<int> bytes, [Map<String, Object?>? args]) async {
          if (bytes.isEmpty) {
            // Returning false fails the run, which is the point: a zero-byte image is
            // worse than no image, because it looks like evidence.
            print('screenshot $name came back empty');
            return false;
          }

          final File file = File('$_outputDir/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
          print('wrote ${file.path} (${bytes.length} bytes)');
          return true;
        },
    // The default handler dumps every screenshot's bytes into a JSON file beside
    // them. The PNGs are the output; the JSON is tens of megabytes of nothing.
    responseDataCallback: null,
  );
}
