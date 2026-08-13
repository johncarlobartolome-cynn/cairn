import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/cairn_back_button.dart';
import '../../shared/widgets/empty_state_page.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/stat_tile.dart';
import 'peak_facts.dart';

/// One peak: its name and the four facts the design puts in a 2x2 grid.
///
/// Pushed over the nav shell, so the floating nav is not on screen and no scroll
/// view here owes it clearance.
///
/// The photo hero, the frosted sheet, the jump-off point, the climb history and
/// the Mark climbed button are all still to come. E2 brings the photography and
/// the peak data, E3 brings marking.
class PeakDetailScreen extends ConsumerWidget {
  const PeakDetailScreen({required this.mountainId, super.key});

  /// Null when the `:id` segment was not a number. Handled exactly like an id
  /// with no row behind it, because to a reader they are the same miss.
  final int? mountainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mountainId;
    if (id == null) return _notFound(context);

    return switch (ref.watch(mountainByIdProvider(id))) {
      AsyncValue(hasError: true) => EmptyStatePage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not open that peak',
        message: 'Something went wrong reading your library.',
        action: _backToPeaks(context),
      ),
      AsyncValue(hasValue: true, value: final peak?) => _Detail(peak: peak),
      // A real answer: the query ran and the library has no peak with that id.
      AsyncValue(hasValue: true) => _notFound(context),
      _ => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
    };
  }

  Widget _notFound(BuildContext context) => EmptyStatePage(
    icon: Icons.landscape_outlined,
    title: 'Peak not found',
    message: 'That peak is not in your library.',
    action: _backToPeaks(context),
  );
}

/// A deep link can land here with nothing to pop, so the way out is explicit
/// rather than left to the bar's back arrow.
Widget _backToPeaks(BuildContext context) => FilledButton(
  onPressed: () => context.go(CairnRoute.peaks),
  child: const Text('Back to peaks'),
);

class _Detail extends StatelessWidget {
  const _Detail({required this.peak});

  final Mountain peak;

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;

    return Scaffold(
      // Bare but for the way out: over the cream ground the band carries nothing
      // else. E2 replaces it with the photo hero and the frosted sheet over it,
      // and takes the same control along.
      appBar: AppBar(leading: const CairnBackButton()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CairnSpace.page,
            0,
            CairnSpace.page,
            CairnSpace.x32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(peak.name, style: text.displayLine2),
              const SizedBox(height: CairnSpace.x24),
              const SectionLabel('Details'),
              const SizedBox(height: CairnSpace.x12),
              _StatGrid(peak: peak),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 2x2 grid, in the order the design lists it.
///
/// Every value is null in the database today, and a StatTile handed an empty
/// value draws a dash. A dash reads as "not recorded", which is exactly what it
/// is. Filling the gap with a plausible elevation would read as fact.
///
/// Two rows of two rather than a GridView, so the tiles take their height from
/// their own content instead of an aspect ratio guessed against one screen width.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.peak});

  final Mountain peak;

  @override
  Widget build(BuildContext context) {
    final tiles = <({String? value, String caption, IconData icon})>[
      (
        value: peak.elevationLabel,
        caption: 'Elevation',
        icon: Icons.height_rounded,
      ),
      (
        value: peak.difficultyLabel,
        caption: 'Difficulty',
        icon: Icons.trending_up_rounded,
      ),
      (value: peak.hoursLabel, caption: 'Hours', icon: Icons.schedule_rounded),
      (value: peak.region, caption: 'Region', icon: Icons.place_outlined),
    ];

    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 2) ...[
          if (row > 0) const SizedBox(height: CairnSpace.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: CairnSpace.cardGap),
                  Expanded(
                    child: StatTile(
                      value: tiles[row + column].value ?? '',
                      caption: tiles[row + column].caption,
                      icon: tiles[row + column].icon,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
