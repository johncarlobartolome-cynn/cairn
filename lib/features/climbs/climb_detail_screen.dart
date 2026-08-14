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

/// One logged climb: the day it happened, who was there, and what was written
/// down.
///
/// Nothing writes a climb until E3, so today every id misses and this screen is
/// its not-found state. The found branch is here anyway, because the alternative
/// is a screen that would answer "not found" to a climb that exists.
///
/// Photos are left out on purpose. Rendering them means resolving a filename
/// against the documents directory at draw time, which belongs with E3 where the
/// picker that writes those files lives.
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
      appBar: AppBar(leading: const CairnBackButton()),
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
              Text(climb.dayLabel, style: text.displayLine2),
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
            ],
          ),
        ),
      ),
    );
  }
}
