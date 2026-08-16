import 'package:flutter/foundation.dart';

import '../../data/providers.dart';
import '../climbs/climb_facts.dart';
import 'peak_facts.dart';

/// What Cairn sends when the user shares a peak, as strings, before anything
/// paints it.
///
/// **The artefact is a picture, not a line of text.** "I climbed Mt. Pulag"
/// pasted into a chat is the feature in the thinnest possible form and carries
/// almost nothing: the receiver gets a claim with no shape to it. A card that
/// says which peak, the day it happened, how high and how hard it is, and how
/// far up the list that puts the climber, is a thing somebody would actually
/// send. It is built on the device out of rows that are already there, so
/// sharing needs no account, no network and no server, which is what an
/// offline single-user app is allowed to spend.
///
/// **No photograph goes on it, and that is a decision rather than an
/// omission.** A climb's photos can hold a companion's face, a plate, a front
/// door, a view of somebody's house. A person tapping share is thinking about
/// the mountain, not auditing what is in the frame, and a picture leaving the
/// phone should be an act they chose rather than a side effect of a tally.
/// Android's own photo share sheet already does that job, deliberately, one
/// picture at a time. Cairn keeps to the facts it can be sure of.
///
/// It is built from the **climb log**, not from the `achievements` table, even
/// though the badge row for a peak exists and carries a date. That date is the
/// moment the badge fired, which is the moment the climb was logged. Log a hike
/// from 2019 this evening and the badge says today. The card says the day of
/// the climb, because a card that names the wrong day is worse than no card,
/// and this is the most public text the app produces.

@immutable
class ShareCard {
  const ShareCard({
    required this.peakName,
    required this.climbedLine,
    required this.facts,
    required this.tally,
    required this.message,
    required this.filename,
  });

  /// The headline. A peak's name exactly as the library holds it.
  final String peakName;

  /// e.g. `Climbed 11 August 2026`. The day of the climb that first put this
  /// peak on the list.
  final String climbedLine;

  /// Elevation and difficulty, already filtered: a peak that records neither
  /// hands back an empty list and the card drops the row.
  ///
  /// Hours and region are left off on purpose. Hours is a plan rather than a
  /// fact about the day, and the province means nothing to a reader who is not
  /// Filipino. Two facts is what fits on one line at this width.
  final List<String> facts;

  /// e.g. `That makes 3 of 6 peaks.`
  ///
  /// Counted **as of this climb**, not as of today: sharing the first peak
  /// after climbing five would otherwise read "6 of 6" under a date from
  /// months ago. Written as a sentence rather than as a labelled number for
  /// the same reason. `PEAKS CLIMBED / 3 of 6` reads as a standing total, and
  /// this is not one.
  final String tally;

  /// The whole card in one line, for the share targets that take text and not
  /// a picture.
  ///
  /// It names no app. The picture already carries the app's name, quietly, and
  /// a line of text that advertises Cairn into somebody else's chat is the
  /// thing a watermark is not allowed to be.
  final String message;

  /// What the receiving app sees the file called, e.g. `cairn-mt-pulag.png`.
  final String filename;

  /// The card for [peak], or null when nobody has climbed it yet.
  ///
  /// [climbs] is the whole log rather than this peak's own climbs, because the
  /// tally is a fact about the collection. [libraryTotal] is what the tally
  /// counts against, so a peak the user adds moves the finish line here with no
  /// change to this code.
  static ShareCard? from({
    required Mountain peak,
    required List<Climb> climbs,
    required int libraryTotal,
  }) {
    // The climb that first put each peak on the list, one per peak.
    final earners = <int, Climb>{};
    for (final Climb climb in climbs) {
      final Climb? held = earners[climb.mountainId];
      if (held == null || _earnedBefore(climb, held)) {
        earners[climb.mountainId] = climb;
      }
    }

    final Climb? earner = earners[peak.id];
    if (earner == null) return null;

    final List<Climb> order = earners.values.toList()..sort(_byEarnedOrder);
    final int ordinal = order.indexOf(earner) + 1;

    // The library is the honest denominator, but a total below the number of
    // peaks already climbed would print "7 of 6". Cascade delete makes that
    // unreachable today; costing one comparison to keep it unreachable is the
    // same call the peaks strip made.
    final int total = libraryTotal < order.length ? order.length : libraryTotal;

    final String day = climbDayLabel(earner.date);

    return ShareCard(
      peakName: peak.name,
      climbedLine: 'Climbed $day',
      // A peak with neither recorded hands back an empty list, and the card
      // drops the whole row rather than drawing a lone separator.
      facts: <String>[?peak.elevationLabel, ?peak.difficultyLabel],
      tally: 'That makes $ordinal of $total peaks.',
      message:
          '${peak.name}, climbed $day. That makes $ordinal of $total peaks.',
      filename: 'cairn-${_slug(peak.name)}.png',
    );
  }
}

/// Whether [a] earned its peak before [b] did.
///
/// The day decides it. Two peaks first climbed on the same day are separated by
/// the row id, which is the order they were logged in, so every peak gets an
/// ordinal of its own and the same log always produces the same numbers.
bool _earnedBefore(Climb a, Climb b) {
  final int byDay = a.date.compareTo(b.date);
  return byDay != 0 ? byDay < 0 : a.id < b.id;
}

int _byEarnedOrder(Climb a, Climb b) {
  final int byDay = a.date.compareTo(b.date);
  return byDay != 0 ? byDay : a.id.compareTo(b.id);
}

/// A peak's name, reduced to something safe to call a file.
///
/// Whitelisted rather than cleaned, the same way a stored photo's extension is:
/// letters and digits survive, everything else becomes a single dash. A user
/// can name a peak anything at all, and a name is not allowed to smuggle a path
/// separator into a filename.
String _slug(String name) {
  final String slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'peak' : slug;
}
