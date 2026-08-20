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
/// **The same sheet also edits a climb that already exists**, opened through
/// [MarkClimbedSheet.edit]. One form rather than two, because the two would be
/// the same four fields under the same rules and the rules would drift apart the
/// first time one of them changed. What differs is the words, the write, and who
/// owns the photographs on the way out.
class MarkClimbedSheet extends ConsumerStatefulWidget {
  const MarkClimbedSheet({
    required int this.mountainId,
    required String this.mountainName,
    super.key,
  }) : climb = null;

  /// The same form, opened on a climb that is already in the log.
  ///
  /// It names no peak, and it needs none. The row is already attached to one and
  /// an edit cannot move it, the acknowledgement has no badge to name, and climb
  /// detail behind the sheet does not say which peak it is either.
  const MarkClimbedSheet.edit({required Climb this.climb, super.key})
    : mountainId = null,
      mountainName = null;

  /// The peak a new climb is being logged against. Null on an edit.
  final int? mountainId;

  /// Shown under the title, so the sheet says which peak it is about, and used
  /// to name the peak's own badge in the acknowledgement. Null on an edit.
  final String? mountainName;

  /// The climb being edited, or null when this is a new one.
  final Climb? climb;

  /// Said when a save came back with no row on it, above the button.
  ///
  /// Only ever for a write that really failed. A tap the sheet refused because
  /// it is already saving says nothing at all, since nothing went wrong and a
  /// line like this in that moment would be the app lying about its own work.
  static const String saveFailedMessage =
      'That climb did not save. Give it another go.';

  /// The same line for an edit, and it says changes rather than climb.
  ///
  /// A climb that failed to save does not exist yet; an edit that failed to save
  /// is a climb still sitting in the log exactly as it was. Telling somebody
  /// their climb did not save in that moment would read as though they had lost
  /// it.
  static const String editFailedMessage =
      'Those changes did not save. Give it another go.';

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
    return _open(
      context,
      MarkClimbedSheet(mountainId: mountainId, mountainName: mountainName),
    );
  }

  /// Opens the sheet on [climb], with everything it already holds in it.
  ///
  /// The photo draft is replaced, inside a scope that reaches no further than
  /// this sheet, with one that starts from the climb's own photographs. See
  /// [ClimbPhotoDraft.new] for why the photos arrive that way rather than by a
  /// call into the notifier afterwards.
  static Future<void> showEdit(BuildContext context, {required Climb climb}) {
    return _open(
      context,
      ProviderScope(
        overrides: <Override>[
          climbPhotoDraftProvider.overrideWith(
            () => ClimbPhotoDraft(existing: climb.photoFilenames),
          ),
        ],
        child: MarkClimbedSheet.edit(climb: climb),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget sheet) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    );
  }

  @override
  ConsumerState<MarkClimbedSheet> createState() => _MarkClimbedSheetState();
}

class _MarkClimbedSheetState extends ConsumerState<MarkClimbedSheet> {
  /// Both start on what the climb already says, which is nothing on a new one.
  late final TextEditingController _companions = TextEditingController(
    text: widget.climb?.companions ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.climb?.notes ?? '',
  );

  /// Today as a calendar day in the phone's own timezone, clock time dropped.
  ///
  /// Held once rather than recomputed, so the picker's upper bound cannot move
  /// under a sheet left open across midnight.
  final DateTime _today = _startOfToday();

  /// The day the sheet is holding: the climb's own on an edit, today on a new
  /// one.
  ///
  /// A stored day reads back as UTC midnight, so its `.year`, `.month` and
  /// `.day` say the stored day in every zone. The picker hands back a local
  /// one. Both are turned into the same kind here, so the sheet holds one
  /// sort of [DateTime] rather than two that only happen to print alike.
  late DateTime _date = _dayOf(widget.climb?.date) ?? _today;

  /// True when this sheet is editing a climb rather than logging one.
  bool get _editing => widget.climb != null;

  /// Set when a save comes back empty-handed. Shown above the button, and the
  /// sheet stays open with everything the user typed still in it.
  String? _failure;

  /// True from the moment a tap is accepted until that save is done with.
  ///
  /// The guard against a second tap, and it is a plain field rather than
  /// anything the build reads because it is read and written with no await in
  /// between. That is the whole of why it works: two taps in one frame both run
  /// [_save] before either of them reaches a write, so the second one finds this
  /// already true and leaves.
  ///
  /// Neither `state.isLoading` on the controller nor the button's own `busy` can
  /// do this job. Both travel through a rebuild, so they start refusing presses
  /// one frame late, and one frame is long enough for a thumb.
  ///
  /// It lives on the sheet rather than in the controller because a refusal has to
  /// be silent, and only the sheet can tell the two answers apart. The controller
  /// reports a failed write by handing back null, so a refusal reported the same
  /// way would put [MarkClimbedSheet.saveFailedMessage] on screen for a climb
  /// that is saving perfectly well.
  bool _saving = false;

  @override
  void dispose() {
    _companions.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime earliest = DateTime(_today.year - _yearsBack);
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // A climb older than the picker's own floor would otherwise open outside
      // its range, which is an assertion rather than a screen. The floor gives
      // way to the day the climb actually holds.
      firstDate: _date.isBefore(earliest) ? _date : earliest,
      lastDate: _today,
      helpText: 'Pick the day you climbed',
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    // First line in the method, and nothing above it may ever await. Every line
    // below is on the far side of one, which is the window two taps in a single
    // frame used to walk through.
    if (_saving) return;
    _saving = true;

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

    final _Said? said = await _write(photoFilenames);

    if (!mounted) return;

    if (said == null) {
      // Let go here, and this is the only place that does. A save that really
      // failed has to be tappable again, so the guard cannot be allowed to latch:
      // that would leave the sheet holding what was typed behind a button that
      // does nothing.
      _saving = false;
      setState(
        () => _failure = _editing
            ? MarkClimbedSheet.editFailedMessage
            : MarkClimbedSheet.saveFailedMessage,
      );
      return;
    }

    // Before the pop, and only on a write that landed. Popping disposes the
    // draft, and the draft deletes every copy the row does not name on the way
    // out, which is right for a sheet that was abandoned and would be data loss
    // one line later than this. The names are what is handed over rather than a
    // flag, so a photo that landed after the row was written goes with it.
    //
    // On an edit this is also the moment a photo the user took off the climb is
    // deleted. The row named it until this write came back.
    photos.keep(photoFilenames);

    navigator.pop();

    messenger.showSnackBar(
      SnackBar(content: Text(said.message), duration: said.duration),
    );
  }

  /// Writes the sheet, and hands back what to say about it.
  ///
  /// Null means the write did not land, and it means that on both paths.
  Future<_Said?> _write(List<String> photoFilenames) async {
    final Climb? editing = widget.climb;

    if (editing != null) {
      final bool changed = await ref
          .read(editClimbControllerProvider.notifier)
          .save(
            id: editing.id,
            date: _date,
            companions: _companions.text,
            notes: _notes.text,
            photoFilenames: photoFilenames,
          );
      // Two plain words, and that is the whole of it. **An edit names no badge,
      // and it is not being modest: it cannot earn one.** Every badge is a
      // function of which peaks have a climb against them, this row keeps its
      // peak, and it was counted the day it was saved. Naming a badge here would
      // congratulate somebody for something they did last week, which is exactly
      // what would make the sentence worthless on the climb that does earn one.
      return changed ? const _Said(climbUpdated, _saidBriefly) : null;
    }

    final ClimbLogged? saved = await ref
        .read(markClimbedControllerProvider.notifier)
        .save(
          mountainId: widget.mountainId!,
          date: _date,
          companions: _companions.text,
          notes: _notes.text,
          photoFilenames: photoFilenames,
        );
    if (saved == null) return null;

    // The one place the app tells somebody what they just earned. See
    // [climbSavedMessage] for the words and why there are no more of them.
    return _Said(
      climbSavedMessage(saved.earned, peakName: widget.mountainName!),
      saved.earned.isEmpty ? _saidBriefly : _saidWithBadges,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final colors = context.cairnColors;
    // One controller or the other, never both. Which of the two is fixed for as
    // long as this sheet is open, so the watch is stable across rebuilds.
    final bool saving = _editing
        ? ref.watch(editClimbControllerProvider).isLoading
        : ref.watch(markClimbedControllerProvider).isLoading;

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
              Text(
                _editing ? 'Edit climb' : 'Mark climbed',
                style: text.screenTitle,
              ),
              // The peak's name, on the path that has one. An edit carries no
              // subtitle rather than a blank line where one would sit.
              if (!_editing) ...[
                const SizedBox(height: CairnSpace.x4),
                Text(widget.mountainName!, style: text.meta),
              ],
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
                label: _editing ? 'Save changes' : 'Save climb',
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

/// One acknowledgement: what to say, and how long to leave it up.
@immutable
class _Said {
  const _Said(this.message, this.duration);

  final String message;
  final Duration duration;
}

/// One calendar day as the picker's own kind of [DateTime], or null.
DateTime? _dayOf(DateTime? day) =>
    day == null ? null : DateTime(day.year, day.month, day.day);

/// The local calendar day, with the clock time dropped.
///
/// `DateTime.now()` is the right source: the day you were on the mountain is
/// the day where you and the mountain were, not the day it was in UTC.
DateTime _startOfToday() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
