import 'dart:typed_data';

import 'package:cairn/data/providers.dart';

/// One handover to the platform, recorded.
typedef SharedImage = ({Uint8List png, String filename, String message});

/// Stands in for the system share sheet.
///
/// The real one opens another process's UI, which no test can tap and no test
/// can read. Everything up to the handover is Cairn's own work, so this records
/// exactly what was handed over and, when [failure] is set, refuses it the way
/// a platform without a share target would.
class FakeShareSheet implements ShareSheet {
  FakeShareSheet({this.failure});

  /// Thrown after the call is recorded, so a test can prove the app got as far
  /// as the platform and still showed the failure.
  final Object? failure;

  final List<SharedImage> calls = <SharedImage>[];

  SharedImage get last => calls.last;

  @override
  Future<void> shareImage({
    required Uint8List png,
    required String filename,
    required String message,
  }) async {
    calls.add((png: png, filename: filename, message: message));
    final Object? refusal = failure;
    if (refusal != null) throw refusal;
  }
}

/// The width and height a PNG declares in its own header.
///
/// Read off the bytes rather than decoded, so the assertion is about the file
/// that would reach the receiving app rather than about what this process can
/// make of it. A PNG is an 8-byte signature, then the IHDR chunk's length and
/// tag, then width and height as big-endian 32-bit numbers.
({int width, int height}) pngSize(Uint8List png) {
  final ByteData view = ByteData.sublistView(png);
  return (width: view.getUint32(16), height: view.getUint32(20));
}

/// Whether [bytes] start with the PNG signature.
bool isPng(Uint8List bytes) {
  const List<int> signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < signature.length) return false;
  for (var i = 0; i < signature.length; i++) {
    if (bytes[i] != signature[i]) return false;
  }
  return true;
}
