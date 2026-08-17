import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';
import '../../../shared/widgets/tap_field.dart';
import '../climbs_providers.dart';
import 'climb_photo.dart';

/// The photo row on the mark-climbed sheet: what is attached so far, and the
/// way to attach more.
///
/// The thumbnails are drawn by [ClimbPhoto], the same widget climb detail uses,
/// so what you see before saving comes off the stored file through the stored
/// filename. A thumbnail that draws here is a photo the app can find later.
class ClimbPhotoField extends ConsumerWidget {
  const ClimbPhotoField({this.enabled = true, super.key});

  /// False while the climb is saving, which closes the picker off the same way
  /// the typed fields grey out.
  final bool enabled;

  /// Big enough to recognise the photo, small enough that four sit in a row on
  /// a phone.
  static const double _thumbSize = 96;

  /// Said when a copy fails part way. The photos that did land stay attached,
  /// so this is an invitation rather than a report of total loss.
  static const String failureMessage =
      'A photo did not attach. Give it another go.';

  static const String addLabel = 'Add photos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<String>> draft = ref.watch(climbPhotoDraftProvider);
    final List<String> filenames = draft.valueOrNull ?? const <String>[];
    final bool working = draft.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filenames.isNotEmpty) ...[
          SizedBox(
            height: _thumbSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filenames.length,
              separatorBuilder: (_, _) => const SizedBox(width: CairnSpace.x12),
              itemBuilder: (context, index) => _Thumb(
                filename: filenames[index],
                size: _thumbSize,
                onRemove: enabled && !working
                    ? () => ref
                          .read(climbPhotoDraftProvider.notifier)
                          .remove(filenames[index])
                    : null,
              ),
            ),
          ),
          const SizedBox(height: CairnSpace.x12),
        ],

        TapField(
          icon: Icons.add_photo_alternate_rounded,
          label: addLabel,
          onTap: enabled && !working
              ? () => ref.read(climbPhotoDraftProvider.notifier).addFromPicker()
              : null,
        ),

        if (draft.hasError) ...[
          const SizedBox(height: CairnSpace.x8),
          Text(
            failureMessage,
            style: context.cairnText.body.copyWith(
              color: context.cairnColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// One attached photo, with the way to take it off again.
class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.filename,
    required this.size,
    required this.onRemove,
  });

  final String filename;
  final double size;

  /// Null while the sheet is busy, so a photo cannot be pulled out from under
  /// a save that is already writing its name.
  final VoidCallback? onRemove;

  /// The remove disc. Smaller than a standard 44 badge because it sits on a 96
  /// thumbnail. The disc that is drawn and the area that answers a thumb are
  /// different sizes on purpose: 24 keeps the photo visible, 44 is what a
  /// finger actually hits, and both fit inside the thumbnail so nothing has to
  /// overhang into the photo beside it.
  static const double _discSize = 24;
  static const double _tapSize = CairnSize.iconBadge;

  @override
  Widget build(BuildContext context) {
    final colors = context.cairnColors;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClimbPhoto(
              filename: filename,
              borderRadius: CairnRadius.fieldAll,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Tooltip(
              message: 'Remove this photo',
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: _tapSize,
                  height: _tapSize,
                  child: Center(
                    child: Container(
                      width: _discSize,
                      height: _discSize,
                      decoration: BoxDecoration(
                        color: colors.brand,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: CairnSize.icon - 2,
                        color: colors.onBrand,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
