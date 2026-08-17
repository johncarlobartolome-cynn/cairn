// Harness support, not a test. No `main`, so `flutter test` never picks it up
// and `flutter drive` compiles it only as an import.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cairn/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// The system picker, stood in for.
///
/// Writes real PNGs into the temporary directory, which is where image_picker
/// leaves its files, and hands back their paths. The files are deliberately not
/// cleaned up here: the app is supposed to copy what it wants to keep, and a
/// test that tidied up for it would hide a failure to do so.
class PaintedPhotoPicker implements PhotoPicker {
  PaintedPhotoPicker(this.count);

  final int count;
  int openings = 0;

  @override
  Future<List<String>> pick() async {
    openings++;
    final dir = await getTemporaryDirectory();
    final int stamp = DateTime.now().microsecondsSinceEpoch;

    return <String>[
      for (var i = 0; i < count; i++)
        await _write('${dir.path}/image_picker_${stamp}_$i.png', i),
    ];
  }

  Future<String> _write(String path, int index) async {
    final Uint8List bytes = await _paintRidge(index);
    await File(path).writeAsBytes(bytes);
    return path;
  }
}

/// A picture, painted rather than bundled.
///
/// A bundled asset would have to ship in the app to be reachable from a device
/// test, and a photo fixture is not something the app should carry. Painting one
/// keeps the harness self-contained and makes the screenshots readable as
/// photographs rather than as grey rectangles.
Future<Uint8List> _paintRidge(int index) async {
  const int width = 1200;
  const int height = 900;
  const Rect frame = Rect.fromLTWH(0, 0, 1200, 900);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, frame);

  final List<List<Color>> skies = <List<Color>>[
    <Color>[const Color(0xFFF6D9A8), const Color(0xFFE39A6B)],
    <Color>[const Color(0xFFBFD8E8), const Color(0xFF7FA6B8)],
  ];
  final List<Color> sky = skies[index % skies.length];

  canvas.drawRect(
    frame,
    Paint()..shader = ui.Gradient.linear(Offset.zero, frame.bottomLeft, sky),
  );

  canvas.drawCircle(
    Offset(width * 0.72, height * 0.26),
    70,
    Paint()..color = const Color(0xFFFFF3DA),
  );

  void ridge(double baseline, Color color, List<Offset> peaks) {
    final path = Path()..moveTo(0, baseline);
    for (final Offset peak in peaks) {
      path.lineTo(peak.dx, peak.dy);
    }
    path
      ..lineTo(width.toDouble(), baseline)
      ..lineTo(width.toDouble(), height.toDouble())
      ..lineTo(0, height.toDouble())
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  ridge(height * 0.62, const Color(0xFF4A7C3F), <Offset>[
    Offset(width * 0.18, height * 0.40),
    Offset(width * 0.34, height * 0.55),
    Offset(width * 0.56, height * 0.30),
    Offset(width * 0.78, height * 0.52),
  ]);
  ridge(height * 0.78, const Color(0xFF1E3A2B), <Offset>[
    Offset(width * 0.26, height * 0.58),
    Offset(width * 0.48, height * 0.70),
    Offset(width * 0.70, height * 0.54),
  ]);

  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
