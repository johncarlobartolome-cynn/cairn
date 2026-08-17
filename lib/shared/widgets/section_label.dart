import 'package:flutter/material.dart';

import '../extensions/theme_context.dart';

/// The tiny uppercase label that sits above every group.
///
/// 11pt SemiBold, wide tracking, muted. Uppercasing happens here so a caller
/// writes the label in normal case and never shouts in a string literal.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {this.trailing, super.key});

  final String text;

  /// Optional widget pinned to the right of the label, e.g. a count or a
  /// "see all" action.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text.toUpperCase(),
      style: context.cairnText.sectionLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (trailing == null) return label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: label),
        trailing!,
      ],
    );
  }
}
