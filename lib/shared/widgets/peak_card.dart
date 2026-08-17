import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';
import 'badge_disc.dart';
import 'cairn_mark.dart';
import 'meta_row.dart';

/// A peak in the list: full-bleed photo inside a rounded card, name and meta
/// row beneath it.
///
/// This card carries the one distinction the app exists to show.
///
/// | State | Treatment |
/// |---|---|
/// | To climb | Photo desaturated to ~30%, cream wash over it, name muted, no mark |
/// | Climbed | Photo at full colour, brand circle mark top-right, name in ink |
///
/// The filter goes through [ColorFiltered], so the treatment is identical
/// whether the card is drawing today's placeholder or the photography E2 will
/// supply. Nothing here changes when the images land.
///
/// The name sits on the card's surface footer rather than over the photo,
/// because the spec puts an unclimbed name in `inkMuted` and muted grey over an
/// arbitrary photograph is unreadable.
///
/// **The change between the two states is animated, the first paint is not, and
/// the animation waits until this card is on screen.** All three matter, and the
/// third is the whole difficulty: the state's own field carries that reasoning,
/// and [CairnPeak.reveal] carries the timing.
class PeakCard extends StatefulWidget {
  const PeakCard({
    required this.name,
    required this.climbed,
    this.image,
    this.meta = const <String?>[],
    this.onTap,
    this.aspectRatio = CairnSize.peakPhotoAspect,
    super.key,
  });

  final String name;

  /// Drives the whole visual treatment, not just the mark.
  final bool climbed;

  /// Null until E2 supplies photography. Nulls and load failures both fall back
  /// to the state-coloured placeholder.
  final ImageProvider? image;

  /// Dot-separated facts under the name. Nulls are dropped, so optional
  /// mountain fields can be passed straight through. The climb date belongs in
  /// here when [climbed] is true.
  final List<String?> meta;

  final VoidCallback? onTap;

  final double aspectRatio;

  @override
  State<PeakCard> createState() => _PeakCardState();
}

class _PeakCardState extends State<PeakCard> {
  /// The state this card is drawing towards: 1 climbed, 0 to climb.
  ///
  /// **It follows [PeakCard.climbed] only while the card is on screen, and that
  /// is what makes the change visible at all.**
  ///
  /// A climb is saved from a sheet over peak detail, so the row lands, the
  /// stream fires and this card is rebuilt climbed while it sits under an opaque
  /// route two screens away. Animating there is the same as not animating: the
  /// reader arrives to a card that has already changed, which is exactly the
  /// problem T26 was opened for.
  ///
  /// Leaning on the framework's own muted tickers was the first attempt and it
  /// does not work. A covered route stops ticking, so the animation would be
  /// scheduled and hold still, but [Ticker.start] stamps its start time from the
  /// frame it was called in, so the first tick after the route is revealed
  /// arrives with however long the reader spent on peak detail already elapsed
  /// and the animation completes in that one frame. Measured, not assumed.
  ///
  /// So the target is held back instead. [TickerMode] is the same signal, read
  /// as an inherited value rather than as a ticker: false while a route covers
  /// this one or another nav branch is showing, and reading it means this card
  /// rebuilds the moment that changes. The card keeps drawing what it was
  /// drawing, and the reveal starts on the frame the list comes back.
  late double _reveal = widget.climbed ? 1 : 0;

  @override
  void didUpdateWidget(PeakCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followIfVisible();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Fires when the route above this one goes, because [TickerMode.of] below is
    // a dependency. That is the frame the held-back change is released on.
    _followIfVisible();
  }

  /// No `setState`: both callers run inside a build cycle that is already going
  /// to rebuild this element, and the value is read on the way through.
  void _followIfVisible() {
    if (!TickerMode.valuesOf(context).enabled) return;
    _reveal = widget.climbed ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      // A fresh tween every build, which is how this widget is meant to be
      // used: it takes the end value and keeps the begin it is already showing.
      tween: Tween<double>(end: _reveal),
      // Reduced motion is an accessibility setting rather than a preference, so
      // it gets the end state in this frame rather than a slower version of the
      // same animation.
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : CairnPeak.reveal,
      curve: CairnPeak.revealCurve,
      builder: (context, reveal, _) => _CardBody(
        name: widget.name,
        reveal: reveal,
        image: widget.image,
        meta: widget.meta,
        onTap: widget.onTap,
        aspectRatio: widget.aspectRatio,
      ),
    );
  }
}

/// The card as drawn at one point in the reveal.
///
/// `reveal` is 0 for a peak to climb and 1 for one that is climbed, and the
/// values between are only ever seen while a card is changing. Both ends are
/// special-cased rather than interpolated to them, so a settled card draws
/// exactly the tree it drew before any of this was animated: no filter over a
/// climbed photograph, no wash, no opacity layer around the mark.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.name,
    required this.reveal,
    required this.image,
    required this.meta,
    required this.onTap,
    required this.aspectRatio,
  });

  final String name;
  final double reveal;
  final ImageProvider? image;
  final List<String?> meta;
  final VoidCallback? onTap;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    final Color nameColour = switch (reveal) {
      <= 0 => colors.inkMuted,
      >= 1 => colors.ink,
      _ => Color.lerp(colors.inkMuted, colors.ink, reveal)!,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: CairnRadius.photoCardAll,
        boxShadow: CairnShadow.card(colors.accent),
      ),
      child: Material(
        color: colors.surface,
        borderRadius: CairnRadius.photoCardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: aspectRatio,
                child: _PeakPhoto(image: image, reveal: reveal),
              ),
              Padding(
                // 12, not 16. That is 8dp off every card and 24dp off a
                // three-row grid, which is a quarter of what the sixth peak
                // needed. The footer holds two short lines at 22 and 13 and 12
                // still clears both; the photo above is what carries the card's
                // generosity.
                padding: const EdgeInsets.all(CairnSpace.x12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No maxLines and no overflow. A peak somebody adds can
                    // carry a name longer than any of the six, and an ellipsis
                    // hides exactly the part that tells two of them apart. The
                    // name wraps to as many lines as it needs and the row it
                    // sits in grows with it, which is what IntrinsicHeight in
                    // the grid is there for.
                    Text(
                      name,
                      style: text.screenTitle.copyWith(color: nameColour),
                    ),
                    if (meta.any((e) => e != null && e.trim().isNotEmpty)) ...[
                      const SizedBox(height: CairnSpace.x4),
                      MetaRow(meta),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo layer: image or placeholder, the unclimbed treatment, and the
/// climbed mark.
class _PeakPhoto extends StatelessWidget {
  const _PeakPhoto({required this.image, required this.reveal});

  final ImageProvider? image;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    Widget layer = image == null
        ? _Placeholder(reveal: reveal)
        : Image(
            image: image!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // A missing file must never take the screen down. See the photo
            // rules in the architecture note.
            errorBuilder: (_, _, _) => _Placeholder(reveal: reveal),
          );

    if (reveal < 1) {
      layer = ColorFiltered(
        colorFilter: CairnPeak.saturation(
          lerpDouble(CairnPeak.unclimbedSaturation, 1, reveal)!,
        ),
        child: layer,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        layer,
        if (reveal < 1) ColoredBox(color: _wash(colors)),
        if (reveal > 0)
          Positioned(
            top: CairnSpace.x12,
            right: CairnSpace.x12,
            child: _ClimbedMark(reveal: reveal),
          ),
      ],
    );
  }

  /// The cream wash, thinning as the colour comes up.
  Color _wash(CairnPalette colors) => reveal <= 0
      ? colors.unclimbedWash
      : colors.ground.withValues(alpha: CairnPeak.washOpacity * (1 - reveal));
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.reveal});

  final double reveal;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    // Interpolated, not switched at a threshold. Until E2 lands the placeholder
    // is the picture, so this is the colour the reveal actually shows.
    final Color fill = switch (reveal) {
      <= 0 => colors.peakPlaceholderUnclimbed,
      >= 1 => colors.peakPlaceholderClimbed,
      _ => Color.lerp(
        colors.peakPlaceholderUnclimbed,
        colors.peakPlaceholderClimbed,
        reveal,
      )!,
    };

    return ColoredBox(
      color: fill,
      child: Center(
        child: Icon(
          // TODO(E2): drop the watermark once real peak photography ships.
          Icons.landscape_outlined,
          size: CairnSize.iconBadge,
          color: colors.surface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _ClimbedMark extends StatelessWidget {
  const _ClimbedMark({required this.reveal});

  /// The card's reveal, not the mark's. The mark's own arrival is read off it,
  /// so the two cannot drift apart.
  final double reveal;

  @override
  Widget build(BuildContext context) {
    // The same disc a peak badge draws on the badges screen, which is the point:
    // one earned peak, one mark, wherever it turns up. T22 drew the mark and
    // closed the stand-in TODO that had sat here since T9.
    const Widget disc = BadgeDisc(
      kind: BadgeKind.peak,
      unlocked: true,
      glyph: CairnMark(),
      size: CairnSize.badgeMark,
      glyphSize: CairnSize.badgeMarkGlyph,
      // The one disc in the app that lands on a picture rather than on a card,
      // so it is the one that takes a ring.
      overImagery: true,
    );

    final double arrived =
        ((reveal - CairnPeak.markArrival) / (1 - CairnPeak.markArrival)).clamp(
          0,
          1,
        );
    // A settled card holds the disc and nothing around it.
    if (arrived >= 1) return disc;

    return Opacity(
      opacity: arrived,
      child: Transform.scale(
        scale: lerpDouble(CairnPeak.markArrivalScale, 1, arrived),
        child: disc,
      ),
    );
  }
}
