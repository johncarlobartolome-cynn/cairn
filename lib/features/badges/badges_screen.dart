import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/badge_disc.dart';
import '../../shared/widgets/badge_tile.dart';
import '../../shared/widgets/cairn_mark.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/pill_nav.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/stat_tile.dart';
import '../climbs/climb_facts.dart';
import 'badge_board.dart';
import 'badges_providers.dart';

/// The badges destination: two counts, then every badge in the app.
///
/// It has stood as an empty state since T5, honestly, because nothing could
/// unlock. T18 made the rows real and this replaces it.
///
/// **Every badge gets a tile, earned or not.** A screen that draws only what
/// has been won says nothing about what is left, and a locked tile that draws
/// only a grey disc is worse: it makes the reader guess. So a locked tile
/// carries the sentence that says how to earn it, and the grid is the full set
/// rather than a highlight reel.
///
/// Peak badges are the library, not the climb log. A peak with a climb against
/// it but no badge row is drawn locked, which is the truth: a save is what
/// unlocks, and two peaks on the emulator were climbed during E3 before any
/// code could. Nothing backfills them.
///
/// It has no [Scaffold] and no [SafeArea] of its own: the nav shell owns both.
class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(badgeBoardProvider);

    return switch (board) {
      AsyncValue(hasError: true) => const _BadgesMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not read your badges',
        message: 'Something went wrong opening them.',
      ),
      AsyncValue(hasValue: true, value: final rows?) => _Board(board: rows),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.board});

  final BadgeBoard board;

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
          _StatRow(board: board),
          const SizedBox(height: CairnSpace.x32),
          const SectionLabel('Milestones'),
          const SizedBox(height: CairnSpace.x12),
          _BadgeGrid(badges: board.milestones),
          // An empty library takes the label with it rather than leaving a
          // heading over nothing. The milestones still stand, and they still
          // say what to do about it.
          if (board.peaks.isNotEmpty) ...[
            const SizedBox(height: CairnSpace.x32),
            const SectionLabel('Peaks'),
            const SizedBox(height: CairnSpace.x12),
            _BadgeGrid(badges: board.peaks),
          ],
        ],
      ),
    );
  }
}

/// Two counts: the whole set, and the milestones inside it.
///
/// Both are read off the tiles below rather than off the climb log, so the row
/// and the grid can never disagree. A peaks-climbed count would be the more
/// obvious second number and it is the wrong one here: this screen is about
/// badges, and the peaks list is where progress up the library belongs. T20
/// puts it there.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.board});

  final BadgeBoard board;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: StatTile(
              value: '${board.earned} of ${board.total}',
              caption: 'Earned',
              // The one highlighted tile on the screen, per the design. This is
              // the headline number.
              emphasised: true,
            ),
          ),
          const SizedBox(width: CairnSpace.cardGap),
          Expanded(
            child: StatTile(
              value: '${board.milestonesEarned} of ${board.milestones.length}',
              caption: 'Milestones',
            ),
          ),
        ],
      ),
    );
  }
}

/// The grid: two badges to a row, each row as tall as its taller tile.
///
/// Rows built by hand rather than with a [GridView], for the reason the stat
/// grid on peak detail gives. A `childAspectRatio` is a guess about how long
/// the strings are, and this grid holds two the code cannot bound: a peak name
/// somebody typed, and the sentence that says how to earn a badge. A row that
/// measures its own content cannot clip either of them.
///
/// Two columns rather than three. At three the cell is about 98dp wide on a
/// phone, which is not enough room for a sentence, and the sentence is the
/// point of a locked tile.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges});

  final List<BadgeView> badges;

  static const int _columns = 2;

  @override
  Widget build(BuildContext context) {
    final rows = (badges.length / _columns).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: CairnSpace.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < _columns; column++) ...[
                  if (column > 0) const SizedBox(width: CairnSpace.cardGap),
                  Expanded(
                    child: switch (row * _columns + column) {
                      // An odd count leaves a hole in the last row. The hole
                      // keeps its half of the width, so a lone tile stays
                      // tile-sized instead of stretching across.
                      final index when index >= badges.length =>
                        const SizedBox.shrink(),
                      final index => _Tile(badge: badges[index]),
                    },
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

class _Tile extends StatelessWidget {
  const _Tile({required this.badge});

  final BadgeView badge;

  @override
  Widget build(BuildContext context) {
    final unlockedAt = badge.unlockedAt;

    return BadgeTile(
      label: badge.name,
      glyph: _glyphFor(badge),
      kind: badge.isMilestone ? BadgeKind.milestone : BadgeKind.peak,
      state: badge.isUnlocked
          ? BadgeTileState.unlocked
          : BadgeTileState.locked,
      // Earned: the day it fired. Locked: what to do about it. Each state
      // shows the one line that is worth reading in that state.
      caption: unlockedAt == null ? badge.condition : climbDayLabel(unlockedAt),
    );
  }
}

/// A glyph per badge, all four distinct so the grid does not read as one shape
/// repeated.
///
/// The glyph is the second cue, not the first. What separates a milestone from a
/// peak badge is the shape of the disc it sits in, because a glyph at 22dp is
/// small enough that two of these were mistaken for each other: "Three peaks"
/// drew a mountain range and a peak badge drew a mountain, and only the fill
/// colour was left to tell them apart. A peak badge now carries [CairnMark], a
/// stack of stones, which is not a mountain in any light.
Widget _glyphFor(BadgeView badge) => switch (badge.milestone) {
  AchievementType.firstClimb => const Icon(Icons.flag_rounded),
  AchievementType.threePeaks => const Icon(Icons.filter_hdr_rounded),
  AchievementType.allPeaks => const Icon(Icons.workspace_premium_rounded),
  // null is a peak badge. perMountain never reaches here: it is a row type, and
  // milestoneOrder leaves it out.
  _ => const CairnMark(),
};

/// The screen's one non-grid state, centred and clear of the nav.
class _BadgesMessage extends StatelessWidget {
  const _BadgesMessage({
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
