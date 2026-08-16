import '../../data/providers.dart';

/// Display strings for a peak's optional facts.
///
/// Only `name` is filled in the database, so every getter here returns null when
/// its field is missing and never a stand-in. The null then travels: a MetaRow
/// drops it, a StatTile draws a dash. Turning a blank into "0 m" or "Unknown"
/// would put a fact on screen that nobody recorded.
///
/// E2 fills the columns in. Nothing here changes when it does.
extension PeakFacts on Mountain {
  /// e.g. `2,922 m`.
  String? get elevationLabel {
    final metres = elevationM;
    return metres == null ? null : '${_grouped(metres)} m';
  }

  /// e.g. `Hard`. Read off the enum's own name, so a tier E4 adds needs nothing
  /// here.
  String? get difficultyLabel {
    final name = difficulty?.name;
    return name == null ? null : name[0].toUpperCase() + name.substring(1);
  }

  /// Where the climb starts, e.g. `DENR Ambangeg Ranger Station, Bokod`.
  ///
  /// Trimmed, and a blank counts as missing. A user-added peak can be saved with
  /// the field left empty, and the detail screen drops the whole section on a
  /// null rather than drawing a label over nothing.
  String? get jumpOffLabel {
    final point = jumpOffPoint?.trim();
    return point == null || point.isEmpty ? null : point;
  }

  /// e.g. `4 hours to the summit`, or `3.5 hours to the summit` for a half
  /// hour. The column is fractional on purpose.
  ///
  /// It was `4 h` under an `HOURS` caption while this was a stat tile. Out of
  /// the tile the abbreviation has nothing to lean on, and a caption is not a
  /// sentence: "hours" alone never said hours of what, and the figure is the
  /// walk up rather than the round trip. So the fact says what it is, in the
  /// words somebody would use standing at the jump-off. Nobody says "four hours
  /// to summit" out loud, which is why the article is here.
  String? get summitTimeLabel {
    final hours = estimatedHours;
    if (hours == null) return null;
    final rounded = (hours * 10).round() / 10;
    final digits = rounded == rounded.roundToDouble()
        ? rounded.toStringAsFixed(0)
        : rounded.toStringAsFixed(1);
    final unit = rounded == 1 ? 'hour' : 'hours';
    return '$digits $unit to the summit';
  }
}

/// Thousands separators, rather than pulling in `intl` for one number on one
/// screen. Elevations are metres above sea level, so no sign handling.
String _grouped(int value) {
  final digits = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}
