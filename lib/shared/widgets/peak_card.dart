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
class PeakCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

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
                child: _PeakPhoto(image: image, climbed: climbed),
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
                    Text(
                      name,
                      style: text.screenTitle.copyWith(
                        color: climbed ? colors.ink : colors.inkMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
  const _PeakPhoto({required this.image, required this.climbed});

  final ImageProvider? image;
  final bool climbed;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    Widget layer = image == null
        ? _Placeholder(climbed: climbed)
        : Image(
            image: image!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // A missing file must never take the screen down. See the photo
            // rules in the architecture note.
            errorBuilder: (_, _, _) => _Placeholder(climbed: climbed),
          );

    if (!climbed) {
      layer = ColorFiltered(
        colorFilter: CairnPeak.saturation(CairnPeak.unclimbedSaturation),
        child: layer,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        layer,
        if (!climbed) ColoredBox(color: colors.unclimbedWash),
        if (climbed)
          Positioned(
            top: CairnSpace.x12,
            right: CairnSpace.x12,
            child: const _ClimbedMark(),
          ),
      ],
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.climbed});

  final bool climbed;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final fill = climbed
        ? colors.peakPlaceholderClimbed
        : colors.peakPlaceholderUnclimbed;

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
  const _ClimbedMark();

  @override
  Widget build(BuildContext context) {
    // The same disc a peak badge draws on the badges screen, which is the point:
    // one earned peak, one mark, wherever it turns up. T22 drew the mark and
    // closed the stand-in TODO that had sat here since T9.
    return const BadgeDisc(
      kind: BadgeKind.peak,
      unlocked: true,
      glyph: CairnMark(),
      size: CairnSize.badgeMark,
      glyphSize: CairnSize.badgeMarkGlyph,
    );
  }
}
