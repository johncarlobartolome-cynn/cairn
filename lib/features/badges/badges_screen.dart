import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pill_nav.dart';

/// The badges destination.
///
/// Empty, and honestly so: no badge can be earned before E3 can mark a climb, so
/// there is nothing for the stat row or the badge grid to draw. E4 builds both.
/// A grid of locked tiles would look finished while standing for nothing.
///
/// It has no [Scaffold] and no [SafeArea] of its own: the nav shell owns both.
class BadgesScreen extends StatelessWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        CairnSpace.page,
        CairnSpace.x24,
        CairnSpace.page,
        // Never a literal. The nav publishes what it costs a scroll view.
        PillNav.clearanceFor(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Your', style: text.displayLine1),
          Text('badges', style: text.displayLine2),
          const SizedBox(height: CairnSpace.x24),
          const EmptyState(
            icon: Icons.workspace_premium_rounded,
            title: 'No badges yet',
            message: 'Mark a peak climbed and the first one unlocks here.',
          ),
        ],
      ),
    );
  }
}
