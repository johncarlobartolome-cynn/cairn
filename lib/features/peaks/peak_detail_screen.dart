import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/cairn_back_button.dart';
import '../../shared/widgets/cairn_button.dart';
import '../../shared/widgets/cairn_mark.dart';
import '../../shared/widgets/empty_state_page.dart';
import '../../shared/widgets/meta_row.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/stat_tile.dart';
import '../climbs/mark_climbed_sheet.dart';
import '../climbs/widgets/climb_history.dart';
import 'peak_facts.dart';
import 'peaks_providers.dart';
import 'share_card.dart';
import 'widgets/share_card_sheet.dart';

/// One peak: its name and where it is, the two figures that decide whether you
/// go, where the climb starts, the action that logs a climb, and every climb
/// already logged against it.
///
/// **T23 rebuilt the top of this screen.** It opened with a 2x2 grid of stat
/// tiles holding elevation, difficulty, hours and region, and all three of the
/// design's complaints about that shape were fair. A tile is a box sized for a
/// measurement, and a province is an attribute rather than a measurement, so
/// region was in a container that could only fail it: not tappable, so a value
/// too long to fit had nowhere to be revealed, which made clipping a dead end
/// instead of a compromise. And four boxes took the top third of the screen for
/// four short facts, in the position the screen's own action should hold, back
/// when there was no action to put there. E3 and E4 gave this screen a Mark
/// climbed button and a climb history, so the room stopped being theoretical.
///
/// The shape now: only elevation and difficulty keep tiles, because both are
/// short enough that nothing can ever clip and both are what somebody weighs
/// before committing to a peak. Region and the walk up read as a subtitle under
/// the name, the way a place and a duration are actually said. The action moved
/// above the climb history, so it stays reachable on a peak with a long log.
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
              // Carries its own gap, because on a peak with neither a region
              // nor an estimate it draws nothing and the gap has to go with it.
              _Subtitle(peak: peak),
              const SizedBox(height: CairnSpace.x24),
              _KeyStats(peak: peak),
              // Nothing at all when the peak has no jump-off recorded, so the
              // gap above it goes with the section.
              if (jumpOff != null) ...[
                const SizedBox(height: CairnSpace.x24),
                _JumpOff(point: jumpOff),
              ],
              // Above the climb history rather than below it, which is the
              // change T23 made to where this button lives.
              //
              // It sat at the foot of the content because there was nothing
              // under it when T15 put it there. A peak climbed four times now
              // carries four rows, and each one pushed the screen's primary
              // action further under the fold: the log grows without limit and
              // the action is a fixed thing that has to stay in reach. Reading
              // order agrees with the thumb here. You decide from the figures
              // and the jump-off, you act, and the history is the record you
              // scroll to afterwards.
              //
              // Still in the scroll flow rather than pinned to the window. A
              // pinned bar would sit over the photo hero E2 has yet to build,
              // and that is a decision for the ticket that builds it.
              const SizedBox(height: CairnSpace.x32),
              _MarkClimbedAction(peak: peak),
              // Same rule as the jump-off: a peak with no climbs shows nothing
              // here, label included.
              if (climbs.isNotEmpty) ...[
                const SizedBox(height: CairnSpace.x32),
                ClimbHistory(climbs: climbs),
              ],
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
      // The app's own mark: the same one the card takes once this is pressed.
      glyph: const CairnMark(),
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

/// Where the climb starts, under its own label below the two tiles.
///
/// Body text, not a stat tile. These strings are an address a person reads and
/// travels to, and one of them carries a registration note as well: "Brgy.
/// Poblacion, Bakun. Register at Bakun National High School or the Municipal
/// Tourism Council." Prose has no length a box can promise to fit, so this
/// wraps to as many lines as it needs and is never truncated. It was the first
/// fact to leave the grid, and T23 moved the other two out behind it.
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

/// Where the peak is and how long the walk up takes, said as one line under
/// the name.
///
/// **Region is an attribute, so it reads as one.** It spent T13 to T22 in a
/// stat tile, where it was the only value on the screen that ever needed
/// shortening: `Batangas (Nasugbu)` drew as `Batangas (` and an ellipsis, the
/// data was cut back to the province to make it fit, and a peak somebody adds
/// themselves could have broken it again. A subtitle has no width to fit
/// inside. It wraps, and a province is never the thing a reader has to hunt
/// for anyway; it is how you place the mountain while you read its name.
///
/// The walk up joins it rather than keeping a box, because a duration next to a
/// place is a sentence people already say: Benguet, four hours to the summit.
///
/// Every field here is nullable and the peaks a user adds may carry neither.
/// [MetaRow] drops a null and glues each separator to the fact that follows it,
/// so one fact draws one fact with no dangling dot, and no facts draws nothing
/// at all, gap included. Absent means absent, which is the same rule the
/// jump-off and the climb history follow.
class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.peak});

  final Mountain peak;

  @override
  Widget build(BuildContext context) {
    final facts = <String?>[peak.region, peak.summitTimeLabel];
    final hasAny = facts.any((f) => f != null && f.trim().isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: CairnSpace.x8),
      child: MetaRow(facts),
    );
  }
}

/// The two figures somebody weighs before deciding to climb, side by side.
///
/// **Only short values sit in boxes now.** An elevation is at most `2,922 m`
/// and a difficulty is one word from a three-value enum, so neither can outgrow
/// a half-width tile at any screen size the app runs on. That is the whole
/// reason these two kept their tiles while region and hours lost theirs: a
/// container that cannot reveal what it hides must never be handed something
/// that might not fit.
///
/// A missing value still draws a dash rather than dropping the tile, and that
/// is deliberately the opposite of what the subtitle does. A subtitle has no
/// promised shape, so a fact that is not there is simply not said. A tile is a
/// labelled slot, and on the peaks a user adds the honest answer is that the
/// app does not know the elevation, not that the peak has none. Inventing a
/// plausible figure would read as fact.
///
/// [IntrinsicHeight] keeps the pair level if one tile wraps to its second line,
/// which is the safety net [StatTile] keeps for user-added peaks even though
/// none of the six seeded values comes close to needing it.
class _KeyStats extends StatelessWidget {
  const _KeyStats({required this.peak});

  final Mountain peak;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatTile(
              value: peak.elevationLabel ?? '',
              caption: 'Elevation',
              icon: Icons.height_rounded,
            ),
          ),
          const SizedBox(width: CairnSpace.cardGap),
          Expanded(
            child: StatTile(
              value: peak.difficultyLabel ?? '',
              caption: 'Difficulty',
              icon: Icons.trending_up_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
