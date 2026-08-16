import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/cairn_back_button.dart';
import '../../shared/widgets/cairn_button.dart';
import '../../shared/widgets/empty_state_page.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/stat_tile.dart';
import '../climbs/mark_climbed_sheet.dart';
import '../climbs/widgets/climb_history.dart';
import 'peak_facts.dart';
import 'peaks_providers.dart';
import 'share_card.dart';
import 'widgets/share_card_sheet.dart';

/// One peak: its name, the four facts the design puts in a 2x2 grid, where the
/// climb starts, every climb logged against it, and the action that logs
/// another.
///
/// Pushed over the nav shell, so the floating nav is not on screen and no scroll
/// view here owes it clearance.
///
/// The photo hero and the frosted sheet are still to come with E2's photography.
class PeakDetailScreen extends ConsumerWidget {
  const PeakDetailScreen({required this.mountainId, super.key});

  /// Null when the `:id` segment was not a number. Handled exactly like an id
  /// with no row behind it, because to a reader they are the same miss.
  final int? mountainId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = mountainId;
    if (id == null) return _notFound(context);

    final peak = ref.watch(mountainByIdProvider(id));
    // Read here rather than inside the history section, so the screen waits for
    // both queries and then paints once, complete. Letting the history arrive a
    // frame late would slide the Mark climbed action down the screen just as a
    // thumb reaches it, and it is the same mistake as drawing a peak card
    // before its climbed state is known.
    final climbs = ref.watch(climbsForMountainProvider(id));
    // The share card joins the same gate rather than arriving on its own. A
    // control that appears a beat after the screen settles is a control the
    // thumb has already moved past, and this one carries a number the rest of
    // the screen does not show.
    final share = ref.watch(shareCardProvider(id));

    return switch ((peak, climbs, share)) {
      (AsyncValue(hasError: true), _, _) ||
      (_, AsyncValue(hasError: true), _) ||
      (_, _, AsyncValue(hasError: true)) => EmptyStatePage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not open that peak',
        message: 'Something went wrong reading your library.',
        action: _backToPeaks(context),
      ),
      // A real answer: the query ran and the library has no peak with that id.
      (AsyncValue(hasValue: true, value: null), _, _) => _notFound(context),
      (
        AsyncValue(hasValue: true, value: final row?),
        AsyncValue(hasValue: true, value: final log?),
        AsyncValue(hasValue: true, value: final card),
      ) =>
        _Detail(peak: row, climbs: log, card: card),
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
  const _Detail({required this.peak, required this.climbs, required this.card});

  final Mountain peak;

  /// Newest first. Empty for a peak nobody has climbed yet.
  final List<Climb> climbs;

  /// What sharing this peak would send, or null while it is unclimbed and
  /// there is nothing to send.
  final ShareCard? card;

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final jumpOff = peak.jumpOffLabel;
    final ShareCard? shareable = card;

    return Scaffold(
      // The way out, and on a climbed peak the way to send it. Over the cream
      // ground the band carries nothing else. E2 replaces it with the photo hero
      // and the frosted sheet over it, and takes both controls along.
      appBar: AppBar(
        leading: const CairnBackButton(),
        actions: <Widget>[if (shareable != null) _ShareAction(card: shareable)],
      ),
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
              // Nothing at all when the peak has no jump-off recorded, so the
              // gap above it goes with the section.
              if (jumpOff != null) ...[
                const SizedBox(height: CairnSpace.x24),
                _JumpOff(point: jumpOff),
              ],
              // Same rule as the jump-off: a peak with no climbs shows nothing
              // here, label included. The section is also where the screen's
              // empty lower half finally goes, which is the half the design's
              // open question calls the layout's real problem.
              if (climbs.isNotEmpty) ...[
                const SizedBox(height: CairnSpace.x24),
                ClimbHistory(climbs: climbs),
              ],
              const SizedBox(height: CairnSpace.x32),
              // In the scroll flow at the foot of the content rather than
              // pinned to the bottom of the window. The screen is short today,
              // so the action is on screen without scrolling, and the design's
              // own open question says peak detail's layout is due a rethink
              // that will decide where the action really lives. Pinning a bar
              // now would build the half of that answer nobody has agreed on.
              _MarkClimbedAction(peak: peak),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's primary action. Opens the sheet that logs a climb.
///
/// It says nothing about whether the peak has been climbed already, and it does
/// not need to: the climbs above it say that, and a peak can be climbed again,
/// so the label stays put on the second visit and every visit after.
class _MarkClimbedAction extends StatelessWidget {
  const _MarkClimbedAction({required this.peak});

  final Mountain peak;

  @override
  Widget build(BuildContext context) {
    return CairnButton(
      label: 'Mark climbed',
      // The same stand-in glyph the climbed mark uses on a peak card. See the
      // TODO in peak_card.dart: a custom three-stone cairn replaces both.
      icon: Icons.terrain_rounded,
      onPressed: () => MarkClimbedSheet.show(
        context,
        mountainId: peak.id,
        mountainName: peak.name,
      ),
    );
  }
}

/// The way to send this peak to somebody, on the peaks the user has climbed.
///
/// **This is the app's one share entry point, and it is here rather than on the
/// badges screen, on climb detail, or on the moment a badge unlocks.**
///
/// The badges grid was the obvious candidate and it is the wrong shape. Two
/// thirds of its tiles cannot be shared: a locked one has nothing behind it,
/// and a milestone means nothing outside the app, since "Three peaks" read by
/// somebody who has never opened Cairn is a claim about a private scoreboard. A
/// grid where some tiles answer a tap and most do not is a worse screen than
/// one where none of them do.
///
/// Climb detail is unambiguous about a date and loses on the fact it holds: a
/// second trip up Batulao is a climb and is not an achievement, so the tally
/// would be wrong on it. It is also three taps from the list.
///
/// The unlock moment is the strongest feeling and the weakest control. It
/// passes. Miss the snack bar and the thing can never be shared again, which
/// makes an achievement's only exit a four-second window.
///
/// So it sits on the peak, one tap from the list, beside the action that
/// created it. In the bar rather than in the body, because the design's own
/// open question already calls this screen's layout overloaded, and a second
/// full-width button under Mark climbed would be an answer to that question
/// nobody has agreed on.
class _ShareAction extends StatelessWidget {
  const _ShareAction({required this.card});

  final ShareCard card;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => ShareCardSheet.show(context, card: card),
      icon: const Icon(Icons.share_rounded),
      // Its own colour and size, like the back arrow beside it, so it reads the
      // same once the bar becomes a photo hero.
      color: context.cairnColors.ink,
      iconSize: CairnSize.navIcon,
      // Says which thing is being shared. A bare share glyph in a bar is the
      // one control on this screen with no words next to it.
      tooltip: 'Share this peak',
    );
  }
}

/// Where the climb starts, under its own label below the stat grid.
///
/// Body text, not a stat tile. These strings are an address a person reads and
/// travels to, and one of them carries a registration note as well: "Brgy.
/// Poblacion, Bakun (register at Bakun National High School or the Municipal
/// Tourism Council)". A tile clips its value to a single line, which is what
/// went wrong with region, so this wraps to as many lines as it needs and is
/// never truncated.
///
/// Only built when the peak has one. The caller owns that check, because the
/// spacing above the section goes with it.
class _JumpOff extends StatelessWidget {
  const _JumpOff({required this.point});

  final String point;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Jump-off point'),
        const SizedBox(height: CairnSpace.x12),
        // Plain Text on purpose: the defaults wrap and never ellipsize, so a
        // maxLines or an overflow here would only take that away.
        Text(point, style: context.cairnText.body),
      ],
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
