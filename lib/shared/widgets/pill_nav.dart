import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// The floating bottom nav: one brand-filled pill holding the app's two
/// destinations.
///
/// Two items is deliberate. The app has exactly two places to be, Peaks and
/// Badges, so the destinations live here as constants rather than as a
/// caller-supplied list that could grow a third by accident.
///
/// It owns its own inset: a [SafeArea] first, then 12 on top of that, so the
/// bar sits 12 above the gesture bar rather than flush against it. That holds
/// whether the caller stacks it over a raw screen or inside an existing
/// [SafeArea]; nesting is harmless, because the outer one has already consumed
/// the inset and the inner one adds nothing.
class PillNav extends StatelessWidget {
  const PillNav({
    required this.currentIndex,
    required this.onSelected,
    super.key,
  });

  /// 0 is Peaks, 1 is Badges.
  final int currentIndex;

  final ValueChanged<int> onSelected;

  static const List<({IconData icon, String label})> destinations = [
    (icon: Icons.hiking_rounded, label: 'Peaks'),
    (icon: Icons.workspace_premium_rounded, label: 'Badges'),
  ];

  /// Height of the bar itself, excluding any inset below it. True by
  /// construction: each destination is [CairnSize.navItem] tall and the pill
  /// adds one padding step on each side.
  static const double barHeight = CairnSize.navItem + CairnSpace.x4 * 2;

  /// Bottom padding a scroll view owes this nav so its last item can scroll
  /// clear instead of dying behind the bar.
  ///
  /// Pass a context from inside the same [SafeArea] the nav sits in. Both read
  /// `MediaQuery.paddingOf`, which a [SafeArea] zeroes once it has consumed the
  /// inset, so the two agree whether they sit inside one or over a raw screen
  /// and the gesture inset is never counted twice.
  ///
  /// Covers: the inset, the nav's own 12 below the bar, the bar, and one more
  /// 12 so content stops short of the bar rather than touching it.
  static double clearanceFor(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom +
      CairnSpace.x12 +
      barHeight +
      CairnSpace.x12;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          left: CairnSpace.page,
          right: CairnSpace.page,
          bottom: CairnSpace.x12,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: CairnRadius.pillAll,
            boxShadow: CairnShadow.card(colors.accent),
          ),
          child: Material(
            color: colors.brand,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(CairnSpace.x4),
              child: Row(
                children: [
                  for (var i = 0; i < destinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        icon: destinations[i].icon,
                        label: destinations[i].label,
                        active: i == currentIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    // Inside a brand-filled bar the active item inverts: onBrand fill with a
    // brand glyph. That keeps "exactly one filled pill" true in both themes,
    // where accent on brand would be too close in value to read.
    final foreground = active
        ? colors.brand
        : colors.onBrand.withValues(alpha: 0.7);

    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          // Fixed height, so PillNav.barHeight stays honest.
          height: CairnSize.navItem,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: active ? colors.onBrand : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: CairnSize.navIcon, color: foreground),
              const SizedBox(width: CairnSpace.x8),
              Flexible(
                child: Text(
                  label,
                  style: context.cairnText.button.copyWith(color: foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
