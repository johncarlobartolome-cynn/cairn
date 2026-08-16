// Alternate entrypoint. Run it with:
//
//   flutter run -t lib/dev/theme_gallery.dart
//
// A living catalogue of the design system: every token and every shared widget
// on one screen, with a light / dark switch. Nothing here reads a provider or
// the database, so the gallery boots on any branch and stays useful for
// eyeballing a token change without walking the real app.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/theme.dart';
import '../app/theme/tokens.dart';
import '../shared/extensions/theme_context.dart';
import '../shared/widgets/badge_disc.dart';
import '../shared/widgets/badge_tile.dart';
import '../shared/widgets/cairn_button.dart';
import '../shared/widgets/cairn_mark.dart';
import '../shared/widgets/filter_pill_row.dart';
import '../shared/widgets/frosted_sheet.dart';
import '../shared/widgets/meta_row.dart';
import '../shared/widgets/peak_card.dart';
import '../shared/widgets/pill_nav.dart';
import '../shared/widgets/section_label.dart';
import '../shared/widgets/stat_tile.dart';

void main() => runApp(const ThemeGalleryApp());

class ThemeGalleryApp extends StatefulWidget {
  const ThemeGalleryApp({super.key});

  @override
  State<ThemeGalleryApp> createState() => _ThemeGalleryAppState();
}

class _ThemeGalleryAppState extends State<ThemeGalleryApp> {
  ThemeMode _mode = ThemeMode.light;

  bool get _isDark => _mode == ThemeMode.dark;

  void _toggle() =>
      setState(() => _mode = _isDark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cairn design system',
      debugShowCheckedModeBanner: false,
      theme: CairnTheme.light,
      darkTheme: CairnTheme.dark,
      themeMode: _mode,
      home: GalleryPage(isDark: _isDark, onToggleBrightness: _toggle),
    );
  }
}

/// The catalogue itself. Split from the app so it can be pumped in a test.
class GalleryPage extends StatefulWidget {
  const GalleryPage({
    required this.isDark,
    required this.onToggleBrightness,
    super.key,
  });

  final bool isDark;
  final VoidCallback onToggleBrightness;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  int _filter = 0;
  int _navIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Status-bar glyphs have to invert with the ground, or dark mode hides
      // the clock behind the deep green.
      value: colors.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          // The Builder puts the clearance read below the SafeArea, where the
          // bottom inset has already been consumed. Reading it from this
          // State's own context would count the gesture inset twice.
          child: Builder(
            builder: (innerContext) => Stack(
              children: [
                ListView(
                  padding: EdgeInsets.only(
                    left: CairnSpace.page,
                    right: CairnSpace.page,
                    top: CairnSpace.x12,
                    // Asked for, never guessed, so the last badge row scrolls
                    // clear of the floating nav instead of dying behind it.
                    bottom: PillNav.clearanceFor(innerContext),
                  ),
                  children: [
                    _Header(
                      isDark: widget.isDark,
                      onToggleBrightness: widget.onToggleBrightness,
                    ),
                    const SizedBox(height: CairnSpace.x24),
                    _Group(
                      label: 'Filter pills',
                      child: FilterPillRow(
                        labels: const ['All', 'To climb', 'Climbed'],
                        selectedIndex: _filter,
                        padding: EdgeInsets.zero,
                        onSelected: (i) => setState(() => _filter = i),
                      ),
                    ),
                    // Side by side, because the pair's point is the contrast.
                    const _Group(
                      label: 'Peak card · climbed vs to climb',
                      child: _PeakCardPair(),
                    ),
                    const _Group(label: 'Stat tiles', child: _StatGrid()),
                    const _Group(label: 'Badge tiles', child: _BadgeGrid()),
                    const _Group(
                      label: 'Frosted sheet over a hero',
                      child: _FrostedDemo(),
                    ),
                    const _Group(
                      label: 'Meta row',
                      child: MetaRow(['2,922 m', 'Hard', '8 h', 'Benguet']),
                    ),
                    const _Group(
                      label: 'Buttons and fields',
                      child: _ControlsDemo(),
                    ),
                    const _Group(label: 'Type scale', child: _TypeSpecimen()),
                    _Group(
                      label: 'Palette',
                      child: _Swatches(palette: colors),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: PillNav(
                    currentIndex: _navIndex,
                    onSelected: (i) => setState(() => _navIndex = i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isDark, required this.onToggleBrightness});

  final bool isDark;
  final VoidCallback onToggleBrightness;

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cairn', style: text.displayLine1),
              Text('design system', style: text.displayLine2),
            ],
          ),
        ),
        IconButton(
          onPressed: onToggleBrightness,
          tooltip: isDark ? 'Switch to light' : 'Switch to dark',
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        ),
      ],
    );
  }
}

/// A labelled section, so the catalogue reads top to bottom.
class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CairnSpace.x24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: CairnSpace.x12),
          child,
        ],
      ),
    );
  }
}

class _PeakCardPair extends StatelessWidget {
  const _PeakCardPair();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PeakCard(
            name: 'Mt. Pulag',
            climbed: true,
            meta: ['2,922 m', 'Climbed 12 Jul'],
          ),
        ),
        SizedBox(width: CairnSpace.cardGap),
        Expanded(
          child: PeakCard(
            name: 'Mt. Apo',
            climbed: false,
            meta: ['2,954 m', 'Hard'],
          ),
        ),
      ],
    );
  }
}

class _TypeSpecimen extends StatelessWidget {
  const _TypeSpecimen();

  @override
  Widget build(BuildContext context) {
    final t = context.cairnText;
    final rows = <(String, TextStyle)>[
      ('Display line 1 · 32/38 Light', t.displayLine1),
      ('Display line 2 · 32/38 Medium', t.displayLine2),
      ('Screen title · 22/28 Medium', t.screenTitle),
      ('Stat value · 20/24 SemiBold', t.statValue),
      ('Body · 15/22 Regular', t.body),
      ('Button · 15 Medium', t.button),
      ('Meta · 13/18 Regular', t.meta),
      ('Section label · 11 SemiBold', t.sectionLabel),
      ('Stat caption · 10 SemiBold', t.statCaption),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, style) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: CairnSpace.x8),
            child: Text(label, style: style),
          ),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.palette});

  final CairnPalette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final swatches = <(String, Color)>[
      ('ground', p.ground),
      ('surface', p.surface),
      ('surfaceAlt', p.surfaceAlt),
      ('brand', p.brand),
      ('onBrand', p.onBrand),
      ('accent', p.accent),
      ('accentSoft', p.accentSoft),
      ('ink', p.ink),
      ('inkMuted', p.inkMuted),
      ('hairline', p.hairline),
      ('gold', p.gold),
    ];

    return Wrap(
      spacing: CairnSpace.x8,
      runSpacing: CairnSpace.x8,
      children: [
        for (final (name, color) in swatches)
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: CairnRadius.fieldAll,
                    border: Border.all(
                      color: p.hairline,
                      width: CairnSize.hairline,
                    ),
                  ),
                ),
                const SizedBox(height: CairnSpace.x4),
                Text(
                  name,
                  style: context.cairnText.statCaption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                value: '2,922 m',
                caption: 'Elevation',
                icon: Icons.height_rounded,
              ),
            ),
            SizedBox(width: CairnSpace.x12),
            Expanded(
              child: StatTile(value: 'Hard', caption: 'Difficulty'),
            ),
          ],
        ),
        SizedBox(height: CairnSpace.x12),
        Row(
          children: [
            Expanded(
              child: StatTile(value: '8 h', caption: 'Est. hours'),
            ),
            SizedBox(width: CairnSpace.x12),
            Expanded(
              child: StatTile(
                value: '3 / 6',
                caption: 'Peaks climbed',
                emphasised: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid();

  @override
  Widget build(BuildContext context) {
    // All four cases, because there are four: two kinds crossed with earned and
    // not. The catalogue carried three until T22, which is how a locked
    // milestone went unnoticed drawing as a locked peak badge in another hat.
    //
    // Two to a row, measured rather than given a `childAspectRatio`, which is
    // both what the real grid does and what stops a caption wrapping to a
    // fourth line from overflowing the cell.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BadgeTile(
                  label: 'Mt. Pulag',
                  glyph: const CairnMark(),
                  kind: BadgeKind.peak,
                  state: BadgeTileState.unlocked,
                  caption: '12 Jul',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: CairnSpace.cardGap),
              const Expanded(
                child: BadgeTile(
                  label: 'Mt. Apo',
                  glyph: CairnMark(),
                  kind: BadgeKind.peak,
                  state: BadgeTileState.locked,
                  caption: 'Climb it.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CairnSpace.cardGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BadgeTile(
                  label: 'First climb',
                  glyph: const Icon(Icons.workspace_premium_rounded),
                  kind: BadgeKind.milestone,
                  state: BadgeTileState.unlocked,
                  caption: '12 Jul',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: CairnSpace.cardGap),
              const Expanded(
                child: BadgeTile(
                  label: 'Three peaks',
                  glyph: Icon(Icons.filter_hdr_rounded),
                  kind: BadgeKind.milestone,
                  state: BadgeTileState.locked,
                  caption: 'Climb three different peaks.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FrostedDemo extends StatelessWidget {
  const _FrostedDemo();

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return ClipRRect(
      borderRadius: CairnRadius.photoCardAll,
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Stands in for the photo hero until E2 supplies one.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [colors.accent, colors.brand],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FrostedSheet(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mt. Pulag', style: context.cairnText.screenTitle),
                    const SizedBox(height: CairnSpace.x4),
                    const MetaRow(['Benguet', '2,922 m', 'Hard']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlsDemo extends StatelessWidget {
  const _ControlsDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CairnButton(
          label: 'Mark climbed',
          glyph: const CairnMark(),
          onPressed: () {},
        ),
        const SizedBox(height: CairnSpace.x8),
        // The same button with nothing to do. The busy state is deliberately
        // not catalogued here: its spinner never stops, and the gallery's smoke
        // test settles the tree before it looks at it.
        const CairnButton(label: 'Save climb', onPressed: null),
        const SizedBox(height: CairnSpace.x12),
        Wrap(
          spacing: CairnSpace.x12,
          runSpacing: CairnSpace.x8,
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('Share')),
            TextButton(onPressed: () {}, child: const Text('Edit')),
          ],
        ),
        const SizedBox(height: CairnSpace.x12),
        const TextField(
          decoration: InputDecoration(hintText: 'Who came along?'),
        ),
        const SizedBox(height: CairnSpace.x16),
        const LinearProgressIndicator(value: 0.5),
      ],
    );
  }
}
