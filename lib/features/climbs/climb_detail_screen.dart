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
import 'climb_facts.dart';
import 'mark_climbed_sheet.dart';
import 'widgets/climb_photo_strip.dart';
import 'widgets/delete_climb_action.dart';

/// One logged climb: the photos, the day it happened, who was there, and what
/// was written down.
///
/// The found branch shipped in T5 against a log that had no climbs in it, on
/// the argument that answering "not found" to a real climb would be wrong
/// rather than unfinished. T15 gave it rows and T17 gave it pictures.
///
/// **T34 gave it a way forward.** Until then a climb saved with only a date drew
/// one line and there was nothing on the screen to act on, which is what Jeysi
/// found using the app on his own phone. A climb is often logged on a trail with
/// no signal and no patience for typing, so the rest of it has to be something
/// you can come back and add.
///
/// **T38 gave it a way out.** Nothing in the app deleted anything, so a climb
/// logged against the wrong peak was permanent. The same gap T34 closed from the
/// other side: the app recorded something and would not let you fix it.
class ClimbDetailScreen extends ConsumerWidget {
  const ClimbDetailScreen({required this.climbId, super.key});

  /// Null when the `:id` segment was not a number. Same miss as an id with no
  /// row behind it.
  final int? climbId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = climbId;
    if (id == null) return _notFound(context);

    return switch (ref.watch(climbByIdProvider(id))) {
      AsyncValue(hasError: true) => EmptyStatePage(
        icon: Icons.cloud_off_rounded,
        title: 'Could not open that climb',
        message: 'Something went wrong reading your log.',
        action: _backToPeaks(context),
      ),
      AsyncValue(hasValue: true, value: final climb?) => _Detail(climb: climb),
      // A real answer: the query ran and the log has no climb with that id.
      AsyncValue(hasValue: true) => _notFound(context),
      _ => const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      ),
    };
  }

  Widget _notFound(BuildContext context) => EmptyStatePage(
    icon: Icons.hiking_rounded,
    title: 'Climb not found',
    message: 'That climb is not in your log yet.',
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
  const _Detail({required this.climb});

  final Climb climb;

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final companions = climb.companions?.trim();
    final notes = climb.notes?.trim();

    return Scaffold(
      // The way out, and the way to finish the entry.
      appBar: AppBar(
        leading: const CairnBackButton(),
        actions: <Widget>[_EditAction(climb: climb)],
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
              // Above the day, because the design lists this screen as photos
              // first and because a field journal entry opens with the picture.
              // No section label over them: they are the hero of the screen,
              // not a group inside it.
              if (climb.photoFilenames.isNotEmpty) ...[
                ClimbPhotoStrip(filenames: climb.photoFilenames),
                const SizedBox(height: CairnSpace.x24),
              ],
              Text(climb.dayLabel, style: text.displayLine2),
              // Only when the day really is all there is. A climb carrying a
              // note already reads as an entry somebody wrote, and asking that
              // person for photographs as well would be the app nagging.
              if (_onlyTheDay(climb)) ...[
                const SizedBox(height: CairnSpace.x24),
                const _Invitation(),
              ],
              if (companions != null && companions.isNotEmpty) ...[
                const SizedBox(height: CairnSpace.x24),
                const SectionLabel('Companions'),
                const SizedBox(height: CairnSpace.x8),
                Text(companions, style: text.body),
              ],
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: CairnSpace.x24),
                const SectionLabel('Notes'),
                const SizedBox(height: CairnSpace.x8),
                Text(notes, style: text.body),
              ],
              // Last on the screen, under everything the climb holds. See
              // [DeleteClimbAction] for why it is here rather than in the bar
              // next to the pencil.
              const SizedBox(height: CairnSpace.x32),
              DeleteClimbAction(climb: climb),
            ],
          ),
        ),
      ),
    );
  }
}

/// True when the climb holds its day and nothing else.
bool _onlyTheDay(Climb climb) =>
    climb.photoFilenames.isEmpty &&
    (climb.companions?.trim().isEmpty ?? true) &&
    (climb.notes?.trim().isEmpty ?? true);

/// What a climb with only a date says instead of nothing.
///
/// **An invitation rather than a form.** The screen used to be one line long and
/// there was no reading of it that told you the rest was still available, so it
/// looked like the app had lost everything but the date. This says what is
/// missing, in the words the sheet's own fields use, and names the way to add
/// it.
///
/// It does not carry a button. The pencil in the bar is the one way in, and it
/// is there on every climb rather than only on the empty ones, so a second
/// control here would be the same action twice on the emptiest screen in the
/// app.
class _Invitation extends StatelessWidget {
  const _Invitation();

  static const String label = 'Still to add';

  static const String message =
      'Who came along, how the climb went, and the photos you took. '
      'Edit this climb to add them.';

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel(label),
        const SizedBox(height: CairnSpace.x8),
        Text(
          message,
          style: context.cairnText.body.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}

/// The way back into the sheet that logged this climb.
///
/// In the bar rather than in the body, for the reason the share control on peak
/// detail is: a full-width button under the notes would be a second primary
/// action on a screen whose layout is already an open question, and it would
/// slide further under the fold with every photograph and every line of prose.
/// The bar keeps it in the same place on a climb with twelve photos and on one
/// with none.
///
/// Same treatment as the share control, down to the colour and the size, so the
/// two read as one family once these bars become photo heroes.
class _EditAction extends StatelessWidget {
  const _EditAction({required this.climb});

  final Climb climb;

  static const String tooltip = 'Edit this climb';

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => MarkClimbedSheet.showEdit(context, climb: climb),
      icon: const Icon(Icons.edit_rounded),
      color: context.cairnColors.ink,
      iconSize: CairnSize.navIcon,
      // Says which thing is being edited. A bare pencil in a bar is a control
      // with no words next to it.
      tooltip: tooltip,
    );
  }
}
