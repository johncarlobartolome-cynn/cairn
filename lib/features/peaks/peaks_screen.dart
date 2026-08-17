import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/filter_pill_row.dart';
import '../../shared/widgets/peak_card.dart';
import '../../shared/widgets/pill_nav.dart';
import 'peak_facts.dart';
import 'peaks_board.dart';
import 'peaks_providers.dart';
import 'widgets/progress_heading.dart';

/// Cards a row. Two, because the app's one job on this screen is showing a set of
/// six at a glance.
const int _columns = 2;

/// The home screen: a greeting, how far up the library the climber is, the three
/// filters, and every peak the filter admits as a photo card, two to a row.
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
/// `peaks_providers.dart` holds the gate now that the strip sits behind it too.
///
/// It has no [Scaffold] and no [SafeArea] of its own: the nav shell owns both, so
/// the floating nav and this list read the same bottom inset.
class PeaksScreen extends ConsumerWidget {
  const PeaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(peaksBoardProvider);

    return switch (board) {
      AsyncValue(hasError: true) => const _PeaksMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not read the library',
        message: 'Something went wrong opening your peaks.',
      ),
      // Nothing to filter and no progress to report, so the whole header goes
      // with the grid rather than sitting over a hole.
      AsyncValue(hasValue: true, value: final rows?) when rows.libraryIsEmpty =>
        const _PeaksMessage(
          icon: Icons.landscape_outlined,
          title: 'No peaks yet',
          message: 'Your library is empty.',
        ),
      AsyncValue(hasValue: true, value: final rows?) => _PeaksList(board: rows),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _PeaksList extends ConsumerWidget {
  const _PeaksList({required this.board});

  final PeaksBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peaks = board.visible;

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
      // One extra for the header, which scrolls away with the rows. A filter
      // that admits nothing puts one card in the grid's place instead of rows,
      // and the header stays where it is: the pill that emptied the list has to
      // remain on screen, or the only way back is a filter the reader can no
      // longer see.
      itemCount: 1 + (peaks.isEmpty ? 1 : rows),
      separatorBuilder: (context, index) =>
          const SizedBox(height: CairnSpace.cardGap),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _Header(
            board: board,
            onSelected: (filter) =>
                ref.read(peakFilterProvider.notifier).select(filter),
          );
        }

        if (peaks.isEmpty) return _NothingHere(board: board);

        final start = (index - 1) * _columns;
        return _PeakRow(
          peaks: peaks.sublist(start, min(start + _columns, peaks.length)),
          climbedIds: board.climbedIds,
        );
      },
    );
  }
}

/// Greeting, progress strip, filter pills. The screen's top matter, in the order
/// the design lists it, and all of it scrolls away with the grid.
///
/// Pinning it was the alternative and it costs the grid the room permanently.
/// This screen's whole argument is that six peaks read as one set, so the row
/// that can scroll off is the one that should.
class _Header extends StatelessWidget {
  const _Header({required this.board, required this.onSelected});

  final PeaksBoard board;
  final ValueChanged<PeakFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The greeting used to read "Your / 6 peaks". The count moved into the
        // heading's progress line, which says how many of the six are climbed
        // and needs the total to say it. Printing 6 twice inside 40dp is the
        // duplication the never-truncate rule tells you to fix in the data
        // rather than in the layout.
        ProgressHeading(climbed: board.climbedTotal, total: board.libraryTotal),
        // 16 rather than 20. The bar is 6dp of quiet and needs less air under
        // it than a block of content would, and the grid below is owed every
        // step that can be spared.
        const SizedBox(height: CairnSpace.x16),
        FilterPillRow(
          labels: <String>[
            for (final filter in PeakFilter.values) filter.label,
          ],
          selectedIndex: board.filter.index,
          onSelected: (index) => onSelected(PeakFilter.values[index]),
          // The row sits inside a list that is already padded to the page
          // margin, so it brings none of its own.
          padding: EdgeInsets.zero,
        ),
        // The list separator adds 12 on top of this, so the pills sit 16 above
        // the first card. Cards are 12 apart from each other and the header is
        // a different kind of thing, so it wants more than a card gap and less
        // than the 24 it had.
        const SizedBox(height: CairnSpace.x4),
      ],
    );
  }
}

/// What a filter says when it admits nothing.
///
/// Both cases are ordinary states rather than errors, and one of them is the
/// best thing that can happen in this app, so neither gets a blank screen. Read
/// these aloud before changing them.
class _NothingHere extends StatelessWidget {
  const _NothingHere({required this.board});

  final PeaksBoard board;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      String title,
      String message,
    ) = switch (board.filter) {
      // Every peak is climbed, which is the whole point of the app, so it reads
      // as the finish line rather than as a list with nothing in it. The trophy
      // is the same glyph the "All peaks" badge wears.
      PeakFilter.toClimb => (
        Icons.workspace_premium_rounded,
        'You have climbed them all',
        'Every peak in your library is done. Nothing left to climb.',
      ),
      // Nothing climbed yet. It says what would put something here, in the
      // words the app uses for the action itself.
      PeakFilter.climbed => (
        Icons.hiking_rounded,
        'Nothing climbed yet',
        'Open a peak and mark it climbed. It shows up here after that.',
      ),
      // Unreachable: an empty library never gets this far, and All admits
      // everything. A screen with no answer is worse than a plain one.
      PeakFilter.all => (
        Icons.landscape_outlined,
        'No peaks yet',
        'Your library is empty.',
      ),
    };

    return EmptyState(icon: icon, title: title, message: message);
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
