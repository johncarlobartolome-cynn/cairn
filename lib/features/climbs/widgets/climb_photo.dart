import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../data/providers.dart';
import '../../../shared/extensions/theme_context.dart';
import 'missing_photo.dart';

/// One stored climb photo, drawn from the file it is in right now.
///
/// The two rules this widget exists to hold:
///
/// **The directory is asked for at build time.** [filename] is all the database
/// holds, and it is joined onto whatever the documents directory is on this
/// build, on this install. Nothing caches that answer, because the app
/// container moves and a remembered path is how a photo gets lost. Move the
/// directory and the same stored filename still draws, which is the property
/// `test/features/climbs/climb_photo_test.dart` pins down.
///
/// **The image has an [Image.errorBuilder].** A missing file is a normal thing
/// rather than an exception. Without the builder the failure takes the whole
/// climb down, and the answer to "one photo is missing" becomes "I cannot open
/// this climb any more".
class ClimbPhoto extends ConsumerWidget {
  const ClimbPhoto({
    required this.filename,
    this.borderRadius = CairnRadius.photoCardAll,
    super.key,
  });

  /// A bare filename, by the rule the column enforces. Never a path.
  final String filename;

  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Directory> directory = ref.watch(
      documentsDirectoryProvider,
    );

    return ClipRRect(
      borderRadius: borderRadius,
      child: switch (directory) {
        AsyncValue(hasValue: true, value: final Directory dir?) => Image.file(
          File('${dir.path}${Platform.pathSeparator}$filename'),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, _, _) => const MissingPhoto(),
        ),
        // No documents directory means no photo either, and it reads the same
        // way to whoever is looking at the screen.
        AsyncValue(hasError: true) => const MissingPhoto(),
        _ => const _PhotoWaiting(),
      },
    );
  }
}

/// The half-frame before the documents directory answers.
///
/// A plain fill rather than a spinner. The wait is one lookup, a spinner would
/// flash, and the screenshot harness reads a spinner as a screen that never
/// finished loading.
class _PhotoWaiting extends StatelessWidget {
  const _PhotoWaiting();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.cairnColors.surfaceAlt);
}
