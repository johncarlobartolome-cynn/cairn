import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/extensions/theme_context.dart';
import '../climbs_providers.dart';
import 'delete_climb_dialog.dart';

/// Said when a climb was still in the log after the delete came back.
///
/// Covers both ways it can fail, because they are the same thing to the person
/// holding the phone: the write threw, or there was no such climb by the time it
/// ran. Either way nothing was taken away and the screen is still showing the
/// climb.
const String deleteFailedMessage =
    'That climb did not delete. Give it another go.';

/// Said once the climb is gone, on the screen it lands on.
///
/// Two plain words, and no offer to put it back. The photographs are deleted
/// from the phone by the time this goes up, so an undo would be a button that
/// could only ever restore half of what went. The confirmation is the safety,
/// and it is asked while there is still something to save.
const String climbDeleted = 'Climb deleted';

/// The way to take a climb out of the log.
///
/// **At the foot of the entry, and that is the placement decision.** The pencil
/// sits in the app bar, top right, and it is the control somebody on this screen
/// reaches for most. A delete beside it would be a thumb's width from the
/// everyday action, and this is the one action in Cairn a mistap cannot be
/// undone. So it is as far from the pencil as the screen goes: you reach it by
/// scrolling past the photographs, the day, the companions and the notes, which
/// is both where a person looks for "get rid of this" and a place a thumb does
/// not arrive by accident.
///
/// Quiet, left aligned and intrinsically sized rather than a full-width button.
/// A destructive control that spans the screen is easy to hit, and easy to hit is
/// the opposite of what this one needs. It is still plainly a control, with a
/// word and a glyph, so nobody has to hunt for it.
class DeleteClimbAction extends ConsumerStatefulWidget {
  const DeleteClimbAction({required this.climb, super.key});

  final Climb climb;

  static const String label = 'Delete this climb';

  @override
  ConsumerState<DeleteClimbAction> createState() => _DeleteClimbActionState();
}

class _DeleteClimbActionState extends ConsumerState<DeleteClimbAction> {
  /// Set when a delete comes back with the climb still in the log. Shown above
  /// the control, and the screen stays exactly as it was.
  String? _failure;

  /// True from the moment a tap is accepted until that delete is done with.
  ///
  /// The guard against a second tap, and a plain field rather than anything the
  /// build reads, because it is read and written with no await in between. That
  /// is the whole of why it works: two taps in one frame both run [_delete]
  /// before either of them has opened anything, so the second one finds this
  /// already true and leaves.
  ///
  /// Neither the controller's `isLoading` nor a disabled control can do this
  /// job. Both travel through a rebuild, so they start refusing presses one
  /// frame late, and one frame is long enough for a thumb. T31 and T32 found the
  /// same shape on Save and on Share.
  ///
  /// **It is set before the confirmation opens, not before the write.** Two taps
  /// in one frame otherwise put up two dialogs, one behind the other. Confirming
  /// both would run two deletes, and the second would find no row and tell
  /// somebody their climb did not delete a moment after it did.
  ///
  /// It lets go on a cancel and on a failure, and nowhere else. A delete that
  /// really failed has to be tappable again, and so does a dialog somebody
  /// dismissed. On the answer that worked the screen is already leaving.
  bool _deleting = false;

  /// [onlyClimbOfPeak] is read in [build] rather than here, so it is the answer
  /// as the screen had it when the tap landed rather than one asked for in the
  /// middle of a gesture.
  Future<void> _delete({required bool onlyClimbOfPeak}) async {
    // First line in the method, and nothing above it may ever await. Every line
    // below is on the far side of one, which is the window two taps in a single
    // frame used to walk through.
    if (_deleting) return;
    _deleting = true;

    // All three read before the first await. The row is about to stop existing
    // and this widget is about to stop being mounted, so nothing below can go
    // looking through a context for them.
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int mountainId = widget.climb.mountainId;

    final bool confirmed = await DeleteClimbDialog.confirm(
      context,
      photoCount: widget.climb.photoFilenames.length,
      onlyClimbOfPeak: onlyClimbOfPeak,
    );
    if (!confirmed) {
      if (!mounted) return;
      _deleting = false;
      return;
    }

    final bool deleted = await ref
        .read(deleteClimbControllerProvider.notifier)
        .delete(id: widget.climb.id);

    if (!deleted) {
      if (!mounted) return;
      _deleting = false;
      setState(() => _failure = deleteFailedMessage);
      return;
    }

    // **Not gated on `mounted`, and that is deliberate.** The row is gone, so
    // the query behind climb detail publishes null and the screen rebuilds
    // itself into "Climb not found", which takes this widget with it. Checking
    // `mounted` here would leave somebody parked on a not-found screen for a
    // climb they deleted on purpose. The router and the messenger were both read
    // before the write for exactly this.
    //
    // It lands on the peak rather than popping, because the peak is the screen
    // where the delete is visible: one row fewer in its climb history, and the
    // card grey again if that was the only climb. `go` rather than `push`, so
    // the deleted climb is not left sitting in the back stack, and back from
    // there reaches the peaks list the same as it always did. A climb opened
    // cold as a deep link lands there too, which beats the peaks list because it
    // is the screen the change happened on.
    router.go(CairnRoute.mountain(mountainId));
    messenger.showSnackBar(const SnackBar(content: Text(climbDeleted)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    // True when the log holds no other climb of this peak, so the peak's badge
    // goes with this one and the confirmation says so.
    //
    // False while the read is still in flight, which is the dialog being told
    // not to say it. A warning hedged into "maybe" is worse than one not given,
    // and this is the same rule peak detail's subtitle follows: a slot with no
    // promised shape simply does not mention an absent fact.
    final bool onlyClimbOfPeak =
        ref
            .watch(climbsForMountainProvider(widget.climb.mountainId))
            .valueOrNull
            ?.length ==
        1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_failure != null) ...[
          Text(
            _failure!,
            style: context.cairnText.body.copyWith(color: colors.error),
          ),
          const SizedBox(height: CairnSpace.x12),
        ],
        TextButton.icon(
          onPressed: () => _delete(onlyClimbOfPeak: onlyClimbOfPeak),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text(DeleteClimbAction.label),
          style: TextButton.styleFrom(
            foregroundColor: colors.error,
            iconSize: CairnSize.icon,
            // Pulls the label back to the page's own left edge. A text button
            // carries horizontal padding of its own, which would otherwise sit
            // this control a few pixels inside every heading above it.
            padding: const EdgeInsets.symmetric(vertical: CairnSpace.x12),
          ),
        ),
      ],
    );
  }
}
