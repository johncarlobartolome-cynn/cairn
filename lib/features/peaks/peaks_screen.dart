import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/peak_card.dart';
import '../../shared/widgets/pill_nav.dart';
import 'peak_facts.dart';

/// The home screen: every peak in the library, one photo card each.
///
/// The rows are real, straight off the database, and the climbed treatment reads
/// the ids that actually have a climb against them. With an empty log every card
/// draws unclimbed, which is the truth rather than a placeholder.
///
/// The progress strip and the All / To climb / Climbed pills from the design spec
/// are not here yet. Neither can say anything until climbs exist, so they land
/// with E3 and E4.
///
/// It has no [Scaffold] and no [SafeArea] of its own: the nav shell owns both, so
/// the floating nav and this list read the same bottom inset.
class PeaksScreen extends ConsumerWidget {
  const PeaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaks = ref.watch(mountainsProvider);

    return switch (peaks) {
      AsyncValue(hasError: true) => const _PeaksMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not read the library',
        message: 'Something went wrong opening your peaks.',
      ),
      AsyncValue(hasValue: true, value: final rows?) when rows.isEmpty =>
        const _PeaksMessage(
          icon: Icons.landscape_outlined,
          title: 'No peaks yet',
          message: 'Your library is empty.',
        ),
      AsyncValue(hasValue: true, value: final rows?) => _PeaksList(peaks: rows),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _PeaksList extends ConsumerWidget {
  const _PeaksList({required this.peaks});

  final List<Mountain> peaks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A peak counts as climbed once it has one climb against it. Taking the
    // value and defaulting to empty keeps the cards on screen while this second
    // stream opens, instead of holding the whole list back for a set that is
    // usually there already.
    final climbed =
        ref.watch(climbedMountainIdsProvider).value ?? const <int>{};

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        CairnSpace.page,
        CairnSpace.x24,
        CairnSpace.page,
        // Never a literal. The nav publishes what it costs a scroll view.
        PillNav.clearanceFor(context),
      ),
      // One extra for the heading, which scrolls away with the list.
      itemCount: peaks.length + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: CairnSpace.cardGap),
      itemBuilder: (context, index) {
        if (index == 0) return _Heading(count: peaks.length);

        final peak = peaks[index - 1];
        return PeakCard(
          name: peak.name,
          climbed: climbed.contains(peak.id),
          meta: [peak.region, peak.elevationLabel, peak.difficultyLabel],
          onTap: () => context.push(CairnRoute.mountain(peak.id)),
        );
      },
    );
  }
}

/// Two lines, two weights, per the design's headline rule.
///
/// The count comes off the rows on screen rather than the six seeds, so a peak
/// the user adds later is counted with no change here.
class _Heading extends StatelessWidget {
  const _Heading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your', style: text.displayLine1),
        Text(count == 1 ? '1 peak' : '$count peaks', style: text.displayLine2),
        // Half the gap to the first card. The list separator adds the other half.
        const SizedBox(height: CairnSpace.x12),
      ],
    );
  }
}

/// The list's two non-list states, centred and clear of the nav.
class _PeaksMessage extends StatelessWidget {
  const _PeaksMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CairnSpace.page,
          CairnSpace.page,
          CairnSpace.page,
          PillNav.clearanceFor(context),
        ),
        child: EmptyState(icon: icon, title: title, message: message),
      ),
    );
  }
}
