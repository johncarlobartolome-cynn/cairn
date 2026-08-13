import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../extensions/theme_context.dart';

/// A horizontal run of filter pills where exactly one is filled.
///
/// Scrolls rather than shrinks, so a longer label set survives a narrow phone.
class FilterPillRow extends StatelessWidget {
  const FilterPillRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: CairnSpace.page),
    super.key,
  });

  final List<String> labels;

  /// Exactly one pill is filled. An index outside [labels] fills none, which is
  /// a caller bug rather than a state this widget supports.
  final int selectedIndex;

  final ValueChanged<int> onSelected;

  /// Applied inside the scroll view, so the first pill sits on the page margin
  /// and can still scroll to the edge.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: CairnSpace.x8),
            _Pill(
              label: labels[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    // The selected pill takes the brand fill, not accentSoft. accentSoft
    // (#E4EDDC) against the cream ground (#F4F1EA) is barely over 1:1, so a
    // soft-filled pill would not read as "selected" at a glance, which is the
    // one job this row has.
    final background = selected ? colors.brand : colors.surface;
    final foreground = selected ? colors.onBrand : colors.inkMuted;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: background,
        shape: StadiumBorder(
          side: selected
              ? BorderSide.none
              : BorderSide(color: colors.hairline, width: CairnSize.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CairnSpace.x16,
              vertical: CairnSpace.x8,
            ),
            child: Text(
              label,
              style: context.cairnText.button.copyWith(color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
