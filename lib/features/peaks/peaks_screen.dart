import 'dart:math' show min;

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

/// Cards a row. Two, because the app's one job on this screen is showing a set of
/// six at a glance.
const int _columns = 2;

/// The home screen: every peak in the library as a photo card, two to a row.
///
/// The rows are real, straight off the database, and the climbed treatment reads
/// the ids that actually have a climb against them.
///
/// The library and the climbed set are waited for together, and no card is
/// built until both have answered. The list used to take whatever the climbed
/// set had and fall back to empty, which let a frame draw every peak unclimbed
/// before that second query came back. T8's review logged it as finding N8 and
/// left it there, since at zero climbs nothing could show.
///
/// T16 went looking for it on a device with four climbs in the file: force-stop,
/// cold launch, screen recording, then every painted frame measured for the
/// saturation of a climbed card against its unclimbed neighbour. It never
/// flashed, with the old code as well as this one. Both queries answer inside
/// the same frame, so the first list ever painted was already right.
///
/// The gate stays anyway. All the recording proves is that one scheduling order
/// won on one device on one day, and the thing at stake is the app appearing to
/// have lost a climb. This makes it a rule instead: cards paint once the app
/// knows what to say about them, and until then the screen says it is reading.
///
/// The progress strip and the All / To climb / Climbed pills from the design
/// spec are not here yet. Both are E4, with the progress view.
///
/// It has no [Scaffold] and no [SafeArea] of its own: the nav shell owns both, so
/// the floating nav and this list read the same bottom inset.
class PeaksScreen extends ConsumerWidget {
  const PeaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaks = ref.watch(mountainsProvider);
    // A peak counts as climbed once it has one climb against it.
    final climbed = ref.watch(climbedMountainIdsProvider);

    return switch ((peaks, climbed)) {
      (AsyncValue(hasError: true), _) ||
      (_, AsyncValue(hasError: true)) => const _PeaksMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not read the library',
        message: 'Something went wrong opening your peaks.',
      ),
      // An empty library needs no climbed set to be sure of itself.
      (AsyncValue(hasValue: true, value: final rows?), _) when rows.isEmpty =>
        const _PeaksMessage(
          icon: Icons.landscape_outlined,
          title: 'No peaks yet',
          message: 'Your library is empty.',
        ),
      (
        AsyncValue(hasValue: true, value: final rows?),
        AsyncValue(hasValue: true, value: final ids?),
      ) => _PeaksList(peaks: rows, climbedIds: ids),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _PeaksList extends StatelessWidget {
  const _PeaksList({required this.peaks, required this.climbedIds});

  final List<Mountain> peaks;
  final Set<int> climbedIds;

  @override
  Widget build(BuildContext context) {
    // Two peaks a row. Six of them then take three rows and land inside one
    // screen, so the climbed and unclimbed pattern reads as a set without
    // scrolling, which is the job the design gives this list. The reference mock
    // runs the same card full width, but it browses one trail at a time and this
    // is a checklist of six. Same card, different container: the card's 4:3 stays
    // exactly as it is.
    final rows = (peaks.length / _columns).ceil();

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        CairnSpace.page,
        CairnSpace.x24,
        CairnSpace.page,
        // Never a literal. The nav publishes what it costs a scroll view.
        PillNav.clearanceFor(context),
      ),
      // One extra for the heading, which scrolls away with the rows.
      itemCount: rows + 1,
      separatorBuilder: (context, index) =>
          const SizedBox(height: CairnSpace.cardGap),
      itemBuilder: (context, index) {
        if (index == 0) return _Heading(count: peaks.length);

        final start = (index - 1) * _columns;
        return _PeakRow(
          peaks: peaks.sublist(start, min(start + _columns, peaks.length)),
          climbedIds: climbedIds,
        );
      },
    );
  }
}

/// One row of the grid, at most [_columns] cards wide.
///
/// A row takes its height from its tallest card and both cards stretch to match,
/// rather than every row being handed one computed extent. Footers are not the
/// same height: a name can run to two lines, a meta row can be there or not, and
/// after E2 it can wrap. Any of those against a fixed extent is a clipped name or
/// an overflow, and neither can happen to a row that measures its own content.
class _PeakRow extends StatelessWidget {
  const _PeakRow({required this.peaks, required this.climbedIds});

  final List<Mountain> peaks;
  final Set<int> climbedIds;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var column = 0; column < _columns; column++) ...[
            if (column > 0) const SizedBox(width: CairnSpace.cardGap),
            Expanded(
              // An odd count leaves a hole in the last row. The hole keeps its
              // half of the width, so a lone card stays card-sized instead of
              // stretching across and reading as a different kind of thing.
              child: column < peaks.length
                  ? _Card(peak: peaks[column], climbedIds: climbedIds)
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.peak, required this.climbedIds});

  final Mountain peak;
  final Set<int> climbedIds;

  @override
  Widget build(BuildContext context) {
    return PeakCard(
      name: peak.name,
      climbed: climbedIds.contains(peak.id),
      // Elevation and difficulty, and deliberately not region.
      //
      // Region was on here when T13 first filled the columns, and it cost the
      // grid the thing the grid is for. Three facts do not fit one line at half
      // width, so every footer ran to a third line, the cards grew, and only
      // two and a half rows survived on screen. Six peaks stopped reading as
      // one set. The wrap was ragged with it too, because each card broke at a
      // different fact depending on how long its region was.
      //
      // Nothing is lost. Region is a stat tile on peak detail, which is where
      // someone asks what province a mountain is in. This list answers "which
      // of my six have I climbed", and a province does not help with that.
      meta: [peak.elevationLabel, peak.difficultyLabel],
      onTap: () => context.push(CairnRoute.mountain(peak.id)),
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
