import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../data/providers.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/cairn_button.dart';
import '../../shared/widgets/section_label.dart';
import '../../shared/widgets/tap_field.dart';
import 'climb_facts.dart';
import 'climbs_providers.dart';
import 'widgets/climb_photo_field.dart';

/// How far back the date picker will go.
///
/// Long enough to log a climb from decades ago, which is the point of letting
/// the date move at all. Forwards it stops at today, because a climb you have
/// not made yet is not a climb.
const int _yearsBack = 50;

/// How long "Climb saved" stays up. Material's own default, kept.
const Duration _saidBriefly = Duration(seconds: 4);

/// How long the acknowledgement stays up when it names a badge.
///
/// Longer, because it is a sentence rather than two words, and the four seconds
/// that suit a confirmation are not enough to read a badge's name, look up at
/// the card, and look back. Six is Material's own guidance for a longer message
/// and it is nowhere near the ten that starts to feel like a thing you have to
/// dismiss.
const Duration _saidWithBadges = Duration(seconds: 6);

/// The sheet that logs a climb: the day you were on the mountain, who came
/// along, and how it went.
///
/// Opens over `/mountain/:id` as a modal sheet rather than as a route of its
/// own, so the peak stays behind it and dismissing it needs no navigation.
///
/// Photos are attached here too. They are copied into the app's own documents
/// directory as soon as they are picked, by [ClimbPhotoDraft], and this sheet
/// only ever handles the bare filenames that come back. See
/// `data/photos/photo_filename.dart` for why that distinction is the one that
/// matters.
class MarkClimbedSheet extends ConsumerStatefulWidget {
  const MarkClimbedSheet({
    required this.mountainId,
    required this.mountainName,
    super.key,
  });

  final int mountainId;

  /// Shown under the title, so the sheet says which peak it is about.
  final String mountainName;

  /// Opens the sheet over whatever route [context] is on.
  ///
  /// Scroll-controlled, so the sheet can grow past the usual half-screen cap
  /// and lift itself over the keyboard while the notes field is being typed
  /// into.
  static Future<void> show(
    BuildContext context, {
    required int mountainId,
    required String mountainName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          MarkClimbedSheet(mountainId: mountainId, mountainName: mountainName),
    );
  }

  @override
  ConsumerState<MarkClimbedSheet> createState() => _MarkClimbedSheetState();
}

class _MarkClimbedSheetState extends ConsumerState<MarkClimbedSheet> {
  final TextEditingController _companions = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  /// Today as a calendar day in the phone's own timezone, clock time dropped.
  ///
  /// Held once rather than recomputed, so the picker's upper bound cannot move
  /// under a sheet left open across midnight.
  final DateTime _today = _startOfToday();

  late DateTime _date = _today;

  /// Set when a save comes back empty-handed. Shown above the button, and the
  /// sheet stays open with everything the user typed still in it.
  String? _failure;

  @override
  void dispose() {
    _companions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_today.year - _yearsBack),
      lastDate: _today,
      helpText: 'Pick the day you climbed',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    // Both read before the await, because the sheet is gone by the time the
    // snack bar goes up and its context cannot be looked through then.
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);

    final ClimbPhotoDraft photos = ref.read(climbPhotoDraftProvider.notifier);

    // Waited for, never read off the provider. A pick that is still copying has
    // published the photos that have landed so far, so reading here wrote the
    // climb with some of them and, on a first pick, with none. The button is
    // already showing busy while copies run, and this is for the tap that got
    // in during the frame before it.
    final List<String> photoFilenames = await photos.settled();
    if (!mounted) return;

    final ClimbLogged? saved = await ref
        .read(markClimbedControllerProvider.notifier)
        .save(
          mountainId: widget.mountainId,
          date: _date,
          companions: _companions.text,
          notes: _notes.text,
          photoFilenames: photoFilenames,
        );

    if (!mounted) return;

    if (saved == null) {
      setState(() => _failure = 'That climb did not save. Give it another go.');
      return;
    }

    // Before the pop, and only on a save that landed. Popping disposes the
    // draft, and the draft deletes every copy the row does not name on the way
    // out, which is right for a sheet that was abandoned and would be data loss
    // one line later than this. The names are what is handed over rather than a
    // flag, so a photo that landed after the row was written goes with it.
    photos.keep(photoFilenames);

    navigator.pop();

    // The one place the app tells somebody what they just earned. See
    // [climbSavedMessage] for the words and why there are no more of them.
    final String message = climbSavedMessage(
      saved.earned,
      peakName: widget.mountainName,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: saved.earned.isEmpty ? _saidBriefly : _saidWithBadges,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final colors = context.cairnColors;
    final bool saving = ref.watch(markClimbedControllerProvider).isLoading;

    // The draft publishes each copy as it lands and stays loading until the last
    // one has, so this is on for exactly as long as photos are being copied in.
    // The button shows it, which is what stops the tap that [_save] otherwise
    // has to wait out.
    final bool copying = ref.watch(climbPhotoDraftProvider).isLoading;

    return Padding(
      // Lifts the sheet off the keyboard, so the field being typed into stays
      // in sight instead of sitting behind it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            CairnSpace.page,
            0,
            CairnSpace.page,
            CairnSpace.x24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark climbed', style: text.screenTitle),
              const SizedBox(height: CairnSpace.x4),
              Text(widget.mountainName, style: text.meta),
              const SizedBox(height: CairnSpace.x24),

              const SectionLabel('Date'),
              const SizedBox(height: CairnSpace.x8),
              _DateField(day: _date, onTap: saving ? null : _pickDate),
              const SizedBox(height: CairnSpace.x20),

              const SectionLabel('Companions'),
              const SizedBox(height: CairnSpace.x8),
              TextField(
                controller: _companions,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Who you climbed with',
                ),
              ),
              const SizedBox(height: CairnSpace.x20),

              const SectionLabel('Notes'),
              const SizedBox(height: CairnSpace.x8),
              TextField(
                controller: _notes,
                enabled: !saving,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                // Grows with what is written, and scrolls inside itself after
                // six lines rather than pushing the button off the sheet.
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'How the climb went',
                ),
              ),
              const SizedBox(height: CairnSpace.x20),

              const SectionLabel('Photos'),
              const SizedBox(height: CairnSpace.x8),
              ClimbPhotoField(enabled: !saving),

              if (_failure != null) ...[
                const SizedBox(height: CairnSpace.x16),
                Text(_failure!, style: text.body.copyWith(color: colors.error)),
              ],

              const SizedBox(height: CairnSpace.x24),
              CairnButton(
                label: 'Save climb',
                glyph: const Icon(Icons.check_rounded),
                busy: saving || copying,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The date, in a field you tap rather than type into.
///
/// Spells the day out in full: the field is as wide as the sheet and has room
/// for the longest month in the year, so nothing here is ever shortened.
///
/// The shape itself moved to [TapField] in T17, when the photo row became its
/// second consumer.
class _DateField extends StatelessWidget {
  const _DateField({required this.day, required this.onTap});

  final DateTime day;

  /// Null while a save is in flight, which greys nothing but stops the picker
  /// opening over a sheet that is already closing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => TapField(
    icon: Icons.event_rounded,
    label: climbDayLabel(day),
    onTap: onTap,
  );
}

/// The local calendar day, with the clock time dropped.
///
/// `DateTime.now()` is the right source: the day you were on the mountain is
/// the day where you and the mountain were, not the day it was in UTC.
DateTime _startOfToday() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
