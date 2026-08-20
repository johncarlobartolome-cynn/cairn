import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';

/// The question asked before a climb is deleted.
///
/// **This dialog is the whole of the safety.** There is no undo behind it and
/// there cannot be: the photographs are files, they are deleted from the phone,
/// and nothing keeps a copy to put back. So the words have to say what goes
/// before it goes, rather than a snack bar offering a way back that does not
/// exist.
///
/// It names what this particular climb is holding rather than what a climb can
/// hold. A line about photographs on a climb that has none would be the app
/// warning about something that is not there, and somebody who reads one warning
/// that does not apply stops reading the next one.
class DeleteClimbDialog extends StatefulWidget {
  const DeleteClimbDialog({
    required this.photoCount,
    required this.onlyClimbOfPeak,
    super.key,
  });

  /// How many photographs the climb is holding. Each one is deleted with it.
  final int photoCount;

  /// True when this is the peak's last climb, so its badge goes too.
  final bool onlyClimbOfPeak;

  static const String title = 'Delete this climb?';

  static const String cancelLabel = 'Cancel';

  /// Says what it does rather than saying yes. A bare "Delete" on a dialog
  /// somebody opened by accident is a word with no object.
  static const String confirmLabel = 'Delete climb';

  /// What the dialog says, built from what the climb actually holds.
  ///
  /// Four sentences at the very most, and each one is a thing that goes. Read
  /// them aloud, which is the only test of a string in this app:
  ///
  /// * `This takes the climb out of your log. Nothing here can be brought back.`
  /// * `This takes the climb out of your log. The photo on it is deleted from
  ///   your phone as well. Nothing here can be brought back.`
  /// * `This takes the climb out of your log. The 4 photos on it are deleted
  ///   from your phone as well. It is your only climb of this peak, so the
  ///   peak's badge goes too. Nothing here can be brought back.`
  ///
  /// The photo count is a digit rather than a word, unlike the counting in
  /// `climb_facts.dart`. A climb earns three badges at the very most, so those
  /// spell out; a climb can hold as many photographs as somebody took, and
  /// spelling out fourteen reads as a stunt.
  ///
  /// The badge line is only said when the app knows it is true. Whether this is
  /// the peak's last climb is a read that may not have answered yet, and a
  /// warning hedged into "maybe" is worse than one not given.
  static String message({
    required int photoCount,
    required bool onlyClimbOfPeak,
  }) {
    return <String>[
      'This takes the climb out of your log.',
      if (photoCount == 1)
        'The photo on it is deleted from your phone as well.'
      else if (photoCount > 1)
        'The $photoCount photos on it are deleted from your phone as well.',
      if (onlyClimbOfPeak)
        "It is your only climb of this peak, so the peak's badge goes too.",
      'Nothing here can be brought back.',
    ].join(' ');
  }

  /// Asks, and answers true only if the delete was confirmed.
  ///
  /// A dismissal is a no, and it has to be: the barrier and the back gesture
  /// both land here, and neither of them is somebody agreeing to lose a
  /// photograph.
  static Future<bool> confirm(
    BuildContext context, {
    required int photoCount,
    required bool onlyClimbOfPeak,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteClimbDialog(
        photoCount: photoCount,
        onlyClimbOfPeak: onlyClimbOfPeak,
      ),
    );
    return answer ?? false;
  }

  @override
  State<DeleteClimbDialog> createState() => _DeleteClimbDialogState();
}

class _DeleteClimbDialogState extends State<DeleteClimbDialog> {
  /// True from the moment either button is accepted.
  ///
  /// The guard against a second tap, and the same shape as the one on the
  /// control that opened this: a plain field, read and written with no await
  /// between them. Two taps on one of these buttons inside a single frame both
  /// reach the handler, and each one pops a route. The first pops this dialog;
  /// the second would pop the screen underneath it, so tapping Cancel twice
  /// would throw somebody off the climb they just decided to keep.
  ///
  /// A disabled button cannot do this job, because it travels through a rebuild
  /// and starts refusing presses one frame late.
  bool _answered = false;

  void _answer(bool confirmed) {
    // First line, and nothing above it awaits.
    if (_answered) return;
    _answered = true;
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return AlertDialog(
      title: Text(DeleteClimbDialog.title, style: text.screenTitle),
      content: Text(
        DeleteClimbDialog.message(
          photoCount: widget.photoCount,
          onlyClimbOfPeak: widget.onlyClimbOfPeak,
        ),
        style: text.body,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: CairnRadius.dataCardAll,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => _answer(false),
          child: const Text(DeleteClimbDialog.cancelLabel),
        ),
        TextButton(
          onPressed: () => _answer(true),
          style: TextButton.styleFrom(foregroundColor: colors.error),
          child: const Text(DeleteClimbDialog.confirmLabel),
        ),
      ],
    );
  }
}
