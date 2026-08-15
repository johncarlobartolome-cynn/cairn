import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../shared/extensions/theme_context.dart';
import '../../shared/widgets/cairn_button.dart';
import '../../shared/widgets/section_label.dart';
import 'climb_facts.dart';
import 'climbs_providers.dart';

/// How far back the date picker will go.
///
/// Long enough to log a climb from decades ago, which is the point of letting
/// the date move at all. Forwards it stops at today, because a climb you have
/// not made yet is not a climb.
const int _yearsBack = 50;

/// The sheet that logs a climb: the day you were on the mountain, who came
/// along, and how it went.
///
/// Opens over `/mountain/:id` as a modal sheet rather than as a route of its
/// own, so the peak stays behind it and dismissing it needs no navigation.
///
/// Photos belong here too and are not built yet. T17 owns them.
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
      builder: (_) => MarkClimbedSheet(
        mountainId: mountainId,
        mountainName: mountainName,
      ),
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

    final int? id = await ref
        .read(markClimbedControllerProvider.notifier)
        .save(
          mountainId: widget.mountainId,
          date: _date,
          companions: _companions.text,
          notes: _notes.text,
        );

    if (!mounted) return;

    if (id == null) {
      setState(() => _failure = 'That climb did not save. Give it another go.');
      return;
    }

    navigator.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Climb saved')));
  }

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final colors = context.cairnColors;
    final bool saving = ref.watch(markClimbedControllerProvider).isLoading;

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

              if (_failure != null) ...[
                const SizedBox(height: CairnSpace.x16),
                Text(
                  _failure!,
                  style: text.body.copyWith(color: colors.error),
                ),
              ],

              const SizedBox(height: CairnSpace.x24),
              CairnButton(
                label: 'Save climb',
                icon: Icons.check_rounded,
                busy: saving,
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
/// Shaped like the text fields beside it so the three read as one form, and it
/// spells the day out in full: a field this wide has room for the longest month
/// in the year, so nothing here is ever shortened.
class _DateField extends StatelessWidget {
  const _DateField({required this.day, required this.onTap});

  final DateTime day;

  /// Null while a save is in flight, which greys nothing but stops the picker
  /// opening over a sheet that is already closing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;
    final text = context.cairnText;

    return Material(
      color: colors.surfaceAlt,
      borderRadius: CairnRadius.fieldAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CairnSize.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CairnSpace.x16,
              vertical: CairnSpace.x12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: CairnSize.icon,
                  color: colors.accent,
                ),
                const SizedBox(width: CairnSpace.x12),
                Expanded(child: Text(climbDayLabel(day), style: text.body)),
                Icon(
                  Icons.chevron_right_rounded,
                  size: CairnSize.icon,
                  color: colors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The local calendar day, with the clock time dropped.
///
/// `DateTime.now()` is the right source: the day you were on the mountain is
/// the day where you and the mountain were, not the day it was in UTC.
DateTime _startOfToday() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
