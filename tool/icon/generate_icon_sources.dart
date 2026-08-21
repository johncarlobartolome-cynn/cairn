// Draws the three 1024 master PNGs the launcher icon is built from, into
// assets/icon/. Nothing here is bundled into the app: assets/icon is not listed
// under `flutter: assets:` in pubspec.yaml, so these files ship in the
// repository and not in the APK.
//
// **Why a script and not a drawing.** The mark belongs to the app already, as a
// CustomPainter in lib/shared/widgets/cairn_mark.dart. Redrawing it by hand in
// an image editor would give a second, drifting copy of the same shape. This
// script restates the one thing the painter holds that a PNG cannot infer, the
// stone geometry, and rasterises from it, so regenerating the icon is a command
// rather than an afternoon.
//
// **The one duplication, named.** _stones and _radii below mirror the private
// constants in _CairnMarkPainter. They are duplicated rather than exported
// because the painter's copies are Rects from dart:ui, and dart:ui only exists
// inside a Flutter engine, which a plain `dart run` script has no way to start.
// Change one, change the other, and look at the result.
//
// Run it through tool/icons.sh, which also fans the masters out to every
// platform size. See docs/app-icon.md.

import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// The design grid the stones are measured on, matching Material's icon grid
/// and _CairnMarkPainter's own.
const double _grid = 24;

/// Bottom, middle, top, as left/top/right/bottom on the 24 grid. Mirrors
/// _CairnMarkPainter._stones.
const List<List<double>> _stones = <List<double>>[
  <double>[2.8, 15.6, 21.2, 21.0],
  <double>[6.0, 9.0, 19.0, 14.0],
  <double>[8.0, 3.0, 15.2, 7.4],
];

/// Corner radius per stone. Mirrors _CairnMarkPainter._radii.
const List<double> _radii = <double>[2.2, 2.1, 2.0];

/// Brand dark green, the `brand` token. The ground the mark sits on.
const int _brand = 0x1E3A2B;

/// Cream, the `onBrand` token. Every glyph on a `brand` fill is this colour, on
/// a peak badge and in the nav, so the icon is not a special case.
const int _onBrand = 0xF4F1EA;

/// Side of every master, and the size the App Store asks for.
const int _side = 1024;

/// How much of the canvas the mark's 24-unit grid spans, per master.
///
/// **Full icon, 0.75.** The drawn stones occupy 18.4 of the 24 units, so the
/// mark itself covers 57.5% of the canvas. Its furthest corner sits 40% of the
/// canvas from the centre, inside the circle a round launcher mask would cut at
/// 50%, so the same file survives being masked square, round or squircle.
const double _fullSpan = 0.75;

/// **Adaptive foreground, 0.56.** An adaptive icon is authored on a 108dp
/// canvas of which only the middle 66dp is guaranteed to survive the mask, so
/// the constraint is a circle of radius 33/108, or 30.6% of the canvas. The
/// mark's furthest corner is 12.85 grid units from its centre, which at this
/// span lands at 30.0%. Drawing the mark any larger is what gets a cairn's
/// bottom stone clipped by a circular mask.
const double _adaptiveSpan = 0.56;

void main() {
  final root = Directory.current.path;
  final out = Directory('$root/assets/icon')..createSync(recursive: true);

  _write('${out.path}/app_icon.png', _opaque(_coverage(_fullSpan)));
  _write(
    '${out.path}/app_icon_foreground.png',
    _tinted(_coverage(_adaptiveSpan), _onBrand),
  );
  _write(
    '${out.path}/app_icon_monochrome.png',
    _tinted(_coverage(_adaptiveSpan), 0xFFFFFF),
  );
}

void _write(String path, img.Image image) {
  File(path).writeAsBytesSync(img.encodePng(image, level: 9));
  stdout.writeln(
    'wrote $path  ${image.width}x${image.height}  '
    '${image.numChannels} channels',
  );
}

/// How much of each pixel the mark covers, 0.0 to 1.0.
///
/// Coverage comes from the signed distance to each rounded rectangle rather
/// than from supersampling: a distance gives a smooth edge at any size, where
/// counting subsamples gives a fixed number of alpha steps and shows them as
/// banding on a 1024 canvas. The stones never touch, so the largest coverage
/// wins outright and there is nothing to blend.
List<double> _coverage(double span) {
  final unit = _side * span / _grid;
  final origin = _side * (1 - span) / 2;
  final coverage = List<double>.filled(_side * _side, 0);

  for (var i = 0; i < _stones.length; i++) {
    final s = _stones[i];
    final left = origin + s[0] * unit;
    final top = origin + s[1] * unit;
    final right = origin + s[2] * unit;
    final bottom = origin + s[3] * unit;
    final radius = _radii[i] * unit;

    final cx = (left + right) / 2;
    final cy = (top + bottom) / 2;
    // Half-extents pulled in by the radius: the straight part of each side.
    final ex = (right - left) / 2 - radius;
    final ey = (bottom - top) / 2 - radius;

    final y0 = math.max(0, (top - 2).floor());
    final y1 = math.min(_side - 1, (bottom + 2).ceil());
    final x0 = math.max(0, (left - 2).floor());
    final x1 = math.min(_side - 1, (right + 2).ceil());

    for (var y = y0; y <= y1; y++) {
      final dy = math.max((y + 0.5 - cy).abs() - ey, 0.0);
      final row = y * _side;
      for (var x = x0; x <= x1; x++) {
        final dx = math.max((x + 0.5 - cx).abs() - ex, 0.0);
        // Distance to the rounded outline. Negative inside.
        final d = math.sqrt(dx * dx + dy * dy) - radius;
        // A one-pixel ramp centred on the outline, the same coverage a GPU
        // would resolve the shape to.
        final alpha = (0.5 - d).clamp(0.0, 1.0);
        if (alpha > coverage[row + x]) {
          coverage[row + x] = alpha;
        }
      }
    }
  }

  return coverage;
}

/// The full icon: cream mark over a brand-green ground, three channels and no
/// alpha at all. **The App Store rejects an icon with an alpha channel**, and a
/// file that never had one cannot lose the argument later.
img.Image _opaque(List<double> coverage) {
  final image = img.Image(width: _side, height: _side, numChannels: 3);
  final bg = _rgb(_brand);
  final fg = _rgb(_onBrand);

  for (final pixel in image) {
    final a = coverage[pixel.y * _side + pixel.x];
    pixel
      ..r = _mix(bg[0], fg[0], a)
      ..g = _mix(bg[1], fg[1], a)
      ..b = _mix(bg[2], fg[2], a);
  }

  return image;
}

/// A layer that carries the mark in one colour on transparency: the adaptive
/// foreground, and the monochrome layer Android 13 tints for a themed icon.
///
/// Every pixel gets the full colour and varies only in alpha, including the
/// ones that are fully transparent. Leaving those black is what puts a dark
/// fringe around a pale glyph the moment anything resamples the layer.
img.Image _tinted(List<double> coverage, int colour) {
  final image = img.Image(width: _side, height: _side, numChannels: 4);
  final c = _rgb(colour);

  for (final pixel in image) {
    pixel
      ..r = c[0]
      ..g = c[1]
      ..b = c[2]
      ..a = (coverage[pixel.y * _side + pixel.x] * 255).round();
  }

  return image;
}

List<int> _rgb(int hex) => <int>[
  (hex >> 16) & 0xFF,
  (hex >> 8) & 0xFF,
  hex & 0xFF,
];

int _mix(int from, int to, double t) => (from + (to - from) * t).round();
