import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cairn/app/theme/theme.dart';
import 'package:cairn/app/theme/tokens.dart';
import 'package:cairn/shared/widgets/badge_disc.dart';
import 'package:cairn/shared/widgets/badge_tile.dart';
import 'package:cairn/shared/widgets/cairn_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Badge types have to be tellable apart with the colour thrown away.
///
/// **The old grid failed this and nobody could see it.** The "Three peaks"
/// milestone drew a mountain range and a peak badge drew a mountain, at 22dp,
/// inside identical 44dp circles. Gold against green was the whole distinction,
/// and roughly one man in twelve has some form of red-green colour blindness
/// and never had it. T22 made the milestone's disc a scalloped seal, so the
/// difference is in the outline.
///
/// **This test renders the real grid, desaturates it, and measures the two
/// silhouettes.** Not an eyeball check: an eyeball check is true on the day
/// somebody looks and says nothing about the palette edit three months later.
///
/// The measurement deliberately knows nothing about colour. It floods the tile
/// background in from the edges of each disc's box and keeps what the flood
/// cannot reach, which is the disc's footprint whatever it happens to be filled
/// with. Two shapes that differ only in colour come out identical, and the test
/// proves that by measuring a control: the same badge in light and in dark,
/// where every colour has changed and the footprint must not move.
///
/// The one thing this cannot see is a disc that has vanished into its card,
/// because a footprint needs an edge to find. `contrast_test.dart` holds that
/// end: an earned disc is kept at 3 to 1 against the card it sits on.
void main() {
  setUpAll(_loadFonts);

  for (final brightness in Brightness.values) {
    final theme = brightness == Brightness.dark ? 'dark' : 'light';

    for (final state in BadgeTileState.values) {
      final earned = state == BadgeTileState.unlocked
          ? 'an earned'
          : 'a locked';

      testWidgets('in greyscale, $earned milestone is not $earned peak badge '
          'in $theme', (tester) async {
        final shot = await _shootGrid(
          tester,
          brightness: brightness,
          states: <BadgeTileState>[state],
        );

        final milestone = shot.footprintAt(0);
        final peak = shot.footprintAt(1);

        // Both discs painted something. A blank footprint would make every
        // comparison below trivially true.
        expect(milestone.area, greaterThan(0));
        expect(peak.area, greaterThan(0));

        // The seal cuts about a sixth out of the circle it is drawn inside, and
        // a locked pair differ over most of their painted area because two thin
        // outlines barely overlap. The bar is set under the filled case, which
        // is the smaller of the two.
        expect(
          milestone.differenceFrom(peak),
          greaterThan(0.08),
          reason:
              'The $earned milestone and the $earned peak badge have the same '
              'silhouette in $theme. Whatever separates them now, it is not '
              'shape, so a reader who cannot see the colours cannot see it.',
        );

        // What the difference actually is, said out loud: one edge is smooth
        // and the other is not. This is the part a reader perceives, and it is
        // worth asserting on its own rather than trusting an area sum to imply
        // it.
        expect(
          peak.edgeSwing,
          lessThan(1.08),
          reason: 'A peak badge is a circle. Its edge should not wander.',
        );
        expect(
          milestone.edgeSwing,
          greaterThan(1.10),
          reason:
              'A milestone is a seal. Its edge has to rise and fall enough to '
              'be seen as bumpy rather than as a rough circle.',
        );
      });
    }
  }

  testWidgets('the measurement ignores colour, which is the point', (
    tester,
  ) async {
    // The control. Every colour in the tile changes between the two themes: the
    // card goes from white to deep green, the disc from near-black to
    // near-white. If the metric were reading colour at all, this would be the
    // largest difference in the file. It has to be about zero.
    final light = await _shootGrid(
      tester,
      brightness: Brightness.light,
      states: <BadgeTileState>[BadgeTileState.unlocked],
    );
    final dark = await _shootGrid(
      tester,
      brightness: Brightness.dark,
      states: <BadgeTileState>[BadgeTileState.unlocked],
    );

    for (var disc = 0; disc < 2; disc++) {
      expect(
        light.footprintAt(disc).differenceFrom(dark.footprintAt(disc)),
        lessThan(0.02),
        reason:
            'Disc $disc changed shape between the themes, so the footprint is '
            'reading colour rather than form and the test above proves '
            'nothing.',
      );
    }
  });

  testWidgets('the app has no mountain glyph left standing in for its own '
      'mark', (tester) async {
    // The stand-in `Icons.terrain_rounded` carried a TODO from T9 and was half
    // of why the two badges looked alike. It is gone from every screen; this
    // keeps it gone.
    final shot = await _shootGrid(
      tester,
      brightness: Brightness.light,
      states: <BadgeTileState>[BadgeTileState.unlocked],
      greyscale: false,
    );
    expect(shot.hasCairnMark, isTrue);
    expect(find.byIcon(Icons.terrain_rounded), findsNothing);
  });

  // The numbers above are the evidence. These are so a person can look as well,
  // which is worth having for a change whose whole subject is what something
  // looks like to somebody who sees colour differently.
  //
  // Off by default and switched on the same way `tool/screenshots.sh` is, since
  // a test suite that writes files wherever it is run is a nuisance.
  final shotDirectory = Platform.environment['CAIRN_SCREENSHOT_DIR'];
  testWidgets(
    'saves the grid, in colour and out of it',
    (tester) async {
      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark ? 'dark' : 'light';
        for (final greyscale in <bool>[false, true]) {
          final shot = await _shootGrid(
            tester,
            brightness: brightness,
            states: BadgeTileState.values,
            greyscale: greyscale,
          );
          shot.save(
            shotDirectory!,
            greyscale ? 'badges-$theme-greyscale' : 'badges-$theme',
          );
        }
      }
    },
    // Set CAIRN_SCREENSHOT_DIR to write the badge grid out as PNGs.
    skip: shotDirectory == null,
  );
}

/// Renders the badge grid and photographs it.
///
/// One row per entry in [states], milestone on the left and peak on the right,
/// which is the order the discs come back in.
///
/// [greyscale] runs the shot through the app's own desaturation matrix, the one
/// a peak card uses on an unclimbed photo, rather than through a conversion
/// written for this test.
Future<_Shot> _shootGrid(
  WidgetTester tester, {
  required Brightness brightness,
  required List<BadgeTileState> states,
  bool greyscale = true,
}) async {
  final boundary = GlobalKey();

  Widget row(BadgeTileState state) {
    final earned = state == BadgeTileState.unlocked;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BadgeTile(
              label: 'Three peaks',
              glyph: const Icon(Icons.filter_hdr_rounded),
              kind: BadgeKind.milestone,
              state: state,
              caption: earned ? '12 Jul' : 'Climb three different peaks.',
            ),
          ),
          const SizedBox(width: CairnSpace.cardGap),
          Expanded(
            child: BadgeTile(
              label: 'Mt. Pulag',
              glyph: const CairnMark(),
              kind: BadgeKind.peak,
              state: state,
              caption: earned ? '12 Jul' : 'Climb it.',
            ),
          ),
        ],
      ),
    );
  }

  final grid = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final (index, state) in states.indexed) ...<Widget>[
        if (index > 0) const SizedBox(height: CairnSpace.cardGap),
        row(state),
      ],
    ],
  );

  final palette = brightness == Brightness.dark
      ? CairnPalette.dark
      : CairnPalette.light;

  // On the page's own ground rather than on nothing, so a saved render shows
  // the cards against the surface they float on.
  final Widget page = ColoredBox(
    color: palette.ground,
    child: Padding(
      padding: const EdgeInsets.all(CairnSpace.x20),
      child: SizedBox(width: _gridWidth, child: grid),
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: brightness == Brightness.dark ? CairnTheme.dark : CairnTheme.light,
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: boundary,
            child: greyscale
                ? ColorFiltered(
                    colorFilter: CairnPeak.saturation(0),
                    child: page,
                  )
                : page,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final render =
      boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  late final Uint8List rgba;
  late final Uint8List png;
  await tester.runAsync(() async {
    final image = await render.toImage(pixelRatio: _pixelRatio);
    rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!.buffer.asUint8List();
    png = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
  });

  final origin = tester.getTopLeft(find.byKey(boundary));
  final found = find.byType(BadgeDisc).evaluate().length;
  final discs = <Rect>[
    for (var i = 0; i < found; i++)
      tester.getRect(find.byType(BadgeDisc).at(i)).shift(-origin),
  ];

  return _Shot(
    rgba: rgba,
    png: png,
    width: (render.size.width * _pixelRatio).round(),
    height: (render.size.height * _pixelRatio).round(),
    discs: discs,
    hasCairnMark: find.byType(CairnMark).evaluate().isNotEmpty,
  );
}

/// Wide enough for two tiles at the width the real grid gives them on a phone.
const double _gridWidth = 371;

/// Three device pixels to the logical one, matching the emulator the app is
/// checked on. It also gives a locked disc's 1dp outline three pixels of body,
/// which the flood fill needs in order to be stopped by it.
const double _pixelRatio = 3;

/// One render of the grid, plus where its discs landed in it.
class _Shot {
  const _Shot({
    required this.rgba,
    required this.png,
    required this.width,
    required this.height,
    required this.discs,
    required this.hasCairnMark,
  });

  final Uint8List rgba;
  final Uint8List png;
  final int width;
  final int height;
  final List<Rect> discs;
  final bool hasCairnMark;

  /// A little room around the disc, so the flood fill starts on background it
  /// is certain about rather than on the shape's own antialiased edge.
  static const int _margin = 4;

  double _luminance(int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(
      rgba[i + 3],
      rgba[i],
      rgba[i + 1],
      rgba[i + 2],
    ).computeLuminance();
  }

  /// The footprint of disc [index]: every pixel the tile's own background
  /// cannot reach by flowing in from the edges.
  ///
  /// This is what makes the measurement colourblind. It never asks what a pixel
  /// is, only whether it is the background, so a gold disc and a green disc of
  /// the same shape produce the same footprint.
  _Footprint footprintAt(int index) {
    final box = discs[index];
    final left = (box.left * _pixelRatio).round() - _margin;
    final top = (box.top * _pixelRatio).round() - _margin;
    final w = (box.width * _pixelRatio).round() + _margin * 2;
    final h = (box.height * _pixelRatio).round() + _margin * 2;

    final background = _luminance(left, top);
    // Generous enough to swallow the card's own dithering, tight enough that a
    // half-covered antialiased edge pixel still counts as paint and blocks the
    // flood.
    const tolerance = 0.02;

    final isBackground = List<bool>.filled(w * h, false);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final lum = _luminance(left + x, top + y);
        isBackground[y * w + x] = (lum - background).abs() <= tolerance;
      }
    }

    final reached = List<bool>.filled(w * h, false);
    final queue = <int>[];
    void seed(int x, int y) {
      final at = y * w + x;
      if (isBackground[at] && !reached[at]) {
        reached[at] = true;
        queue.add(at);
      }
    }

    for (var x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (var y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }

    while (queue.isNotEmpty) {
      final at = queue.removeLast();
      final x = at % w;
      final y = at ~/ w;
      if (x > 0) seed(x - 1, y);
      if (x < w - 1) seed(x + 1, y);
      if (y > 0) seed(x, y - 1);
      if (y < h - 1) seed(x, y + 1);
    }

    return _Footprint(
      inside: <bool>[for (var i = 0; i < w * h; i++) !reached[i]],
      width: w,
      height: h,
    );
  }

  /// Writes the render to [directory] as `t22-<name>.png`.
  void save(String directory, String name) {
    final file = File('$directory/t22-$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png);
    expect(file.lengthSync(), greaterThan(0));
  }
}

/// One disc's silhouette, as a grid of in-or-out.
class _Footprint {
  const _Footprint({
    required this.inside,
    required this.width,
    required this.height,
  });

  final List<bool> inside;
  final int width;
  final int height;

  int get area => inside.where((cell) => cell).length;

  /// How much of the two shapes' combined area belongs to only one of them.
  ///
  /// Zero means the same silhouette. The two footprints are the same size by
  /// construction, both being one disc's box at one pixel ratio.
  double differenceFrom(_Footprint other) {
    expect(other.width, width);
    expect(other.height, height);

    var union = 0;
    var only = 0;
    for (var i = 0; i < inside.length; i++) {
      if (inside[i] || other.inside[i]) union++;
      if (inside[i] != other.inside[i]) only++;
    }
    return union == 0 ? 0 : only / union;
  }

  /// The ratio of the shape's widest reach to its narrowest, measured from the
  /// centre at one degree steps.
  ///
  /// A circle comes out at about 1. A ten-lobed seal swings between its outer
  /// radius and 84% of it, so it comes out near 1.19. This is the bumpiness of
  /// the edge, stated as a number.
  double get edgeSwing {
    final cx = width / 2;
    final cy = height / 2;
    final limit = math.min(cx, cy);

    var shortest = double.infinity;
    var longest = 0.0;

    for (var degree = 0; degree < 360; degree++) {
      final angle = degree * math.pi / 180;
      final dx = math.cos(angle);
      final dy = math.sin(angle);

      var reach = 0.0;
      for (var r = 0.0; r < limit; r += 0.25) {
        final x = (cx + dx * r).round();
        final y = (cy + dy * r).round();
        if (x < 0 || y < 0 || x >= width || y >= height) break;
        if (!inside[y * width + x]) break;
        reach = r;
      }

      shortest = math.min(shortest, reach);
      longest = math.max(longest, reach);
    }

    return shortest <= 0 ? double.infinity : longest / shortest;
  }
}

/// Loads the fonts the app ships with, so a saved render reads like the app
/// rather than like a row of boxes.
///
/// Nothing measured in this file depends on it. Every assertion is on a disc's
/// footprint, and a disc is painted rather than typed, so a missing icon font
/// would change the pictures and not the numbers.
Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    var found = false;
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      found = true;
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    if (found) await loader.load();
  }

  await load(CairnType.family, <String>[
    'assets/fonts/Manrope-Light.ttf',
    'assets/fonts/Manrope-Regular.ttf',
    'assets/fonts/Manrope-Medium.ttf',
    'assets/fonts/Manrope-SemiBold.ttf',
  ]);

  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk != null) {
    await load('MaterialIcons', <String>[
      '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }
}
