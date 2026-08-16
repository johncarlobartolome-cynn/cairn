import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../shared/extensions/theme_context.dart';
import '../../../shared/widgets/cairn_button.dart';
import '../peaks_providers.dart';
import '../share_card.dart';
import 'share_card_view.dart';

/// How much bigger the exported picture is than the card on screen.
///
/// 3 rather than the device's own pixel ratio, so the file is the same size off
/// every handset. A 360-wide card exports at 1080 across, which is a phone
/// screen's worth of detail and still a small enough PNG to send over a slow
/// connection.
const double _exportPixelRatio = 3;

/// What the user sees before anything leaves the phone.
///
/// The card is drawn here, full size, and the button under it sends exactly
/// those pixels. A preview is the honest shape for this: the receiving end is
/// somebody else's chat thread, and the last chance to look at what is being
/// sent should come before it is sent rather than after. It also gives the
/// privacy line somewhere to sit, and the failure line a place to appear
/// without a snack bar covering the thing it is about.
class ShareCardSheet extends ConsumerStatefulWidget {
  const ShareCardSheet({required this.card, super.key});

  final ShareCard card;

  /// Opens the sheet over whatever route [context] is on.
  ///
  /// Scroll-controlled, so a card made taller by a long peak name or a large
  /// system font still scrolls inside the sheet instead of being cut off by the
  /// usual half-screen cap.
  static Future<void> show(BuildContext context, {required ShareCard card}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ShareCardSheet(card: card),
    );
  }

  @override
  ConsumerState<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends ConsumerState<ShareCardSheet> {
  /// Wraps the card on screen. The export is taken off this boundary's own
  /// layer, so the picture and the preview cannot drift apart.
  final GlobalKey _canvas = GlobalKey();

  /// Set when nothing was handed over. Shown above the button, and the sheet
  /// stays open with the card still on it.
  String? _failure;

  Future<void> _share() async {
    final bool shared = await ref
        .read(shareCardControllerProvider.notifier)
        .share(card: widget.card, render: _render);

    if (!mounted) return;
    setState(() {
      _failure = shared ? null : 'That did not share. Give it another go.';
    });
  }

  /// The card as PNG bytes, or null when it is not on screen to be rendered.
  ///
  /// The boundary paints the card at its own logical size whatever an ancestor
  /// does to it, so a card scaled down to fit a narrow phone still exports at
  /// full size.
  Future<Uint8List?> _render() async {
    final RenderObject? object = _canvas.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    final ui.Image image = await object.toImage(pixelRatio: _exportPixelRatio);
    try {
      final ByteData? bytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return bytes?.buffer.asUint8List();
    } finally {
      // Freed here rather than left to the collector: a full-size bitmap is
      // held outside the Dart heap, so nothing would hurry it along.
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = context.cairnText;
    final colors = context.cairnColors;
    final bool sharing = ref.watch(shareCardControllerProvider).isLoading;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CairnSpace.page,
          0,
          CairnSpace.page,
          CairnSpace.x24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share this peak', style: text.screenTitle),
            const SizedBox(height: CairnSpace.x4),
            // The whole privacy answer, in the two sentences somebody would
            // actually say. Photos are the reason it is here: a climb can carry
            // faces and front doors, and none of that is on the card.
            Text(
              'Only this card leaves your phone. Your notes and photos stay '
              'here.',
              style: text.meta,
            ),
            const SizedBox(height: CairnSpace.x24),
            Center(
              child: FittedBox(
                // Shrinks on a phone too narrow for the card and leaves it
                // alone everywhere else. The export is unaffected either way.
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _canvas,
                  child: ShareCardView(card: widget.card),
                ),
              ),
            ),
            if (_failure != null) ...[
              const SizedBox(height: CairnSpace.x16),
              Text(_failure!, style: text.body.copyWith(color: colors.error)),
            ],
            const SizedBox(height: CairnSpace.x24),
            CairnButton(
              label: 'Share',
              icon: Icons.share_rounded,
              busy: sharing,
              onPressed: _share,
            ),
          ],
        ),
      ),
    );
  }
}
