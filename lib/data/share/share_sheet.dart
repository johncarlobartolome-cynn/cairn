import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Where a finished picture goes when the user asks to send it.
///
/// An interface rather than a direct call to `share_plus`, for the same reason
/// `PhotoPicker` is one: the system share sheet belongs to another process and
/// no test on a device or on the host can tap it. Everything up to the handover
/// is Cairn's own work and has to be provable, so the plugin sits behind a seam
/// and a test asserts what was handed over.
abstract interface class ShareSheet {
  /// Hands one PNG and one line of text to the platform's share sheet.
  ///
  /// [filename] is what the receiving app sees. [message] rides alongside for
  /// the targets that take text as well as a picture, and stands in on the ones
  /// that take text only.
  ///
  /// Throws if the platform refuses. The caller decides what to say.
  Future<void> shareImage({
    required Uint8List png,
    required String filename,
    required String message,
  });
}

/// The real one.
///
/// The bytes are handed over in memory and `share_plus` writes them into the
/// temporary directory itself. Cairn never puts a share file in the documents
/// directory: that folder is the app's own data, holding `cairn.sqlite` and
/// every climb photo, and a picture built to be thrown away has no business
/// next to files the app must not lose.
///
/// `fileNameOverrides` is not decoration. `XFile.fromData` drops its `name` on
/// every platform except web, so without the override the receiving app is
/// offered a generated name instead of the peak's.
class SystemShareSheet implements ShareSheet {
  const SystemShareSheet();

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String filename,
    required String message,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(png, mimeType: 'image/png', name: filename),
        ],
        fileNameOverrides: <String>[filename],
        text: message,
      ),
    );
  }
}
