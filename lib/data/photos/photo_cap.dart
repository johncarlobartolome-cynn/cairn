/// How large a stored climb photo is allowed to be, and the work that makes one
/// obey.
///
/// The app's whole storage is the phone and there is no server to push a photo
/// to. T17 copied what the picker handed over, untouched, so a hike with twenty
/// photos off a modern camera cost well over a hundred megabytes of the user's
/// device. Nothing on screen was any better for it: the photo is drawn at the
/// width of a card.
///
/// Nothing here knows about files. It takes bytes and hands back bytes, which
/// is what lets the same rule serve a photo arriving from the picker and a
/// photo that has been sitting in the documents directory since E3.
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The longest side a stored photo may have, in pixels.
///
/// 2048, and the number was measured rather than assumed. A 2880x2160
/// photograph of 5,783,132 bytes re-encodes to 724,783 at this cap, so a
/// twenty-photo hike goes from about 110 MB to about 14 MB. Rendered at the
/// width a phone actually gives it, the capped copy and the original are the
/// same picture; the vine rows in the test photograph, which is the finest
/// repeating detail in it, survive intact.
///
/// Why not lower. A phone screen is around 1080 pixels wide, so 1440 would
/// already cover the app as it stands and would save another 350 KB a photo.
/// 2048 keeps a little over the screen's own count, which is what a pinch, a
/// future full-screen viewer, or a small print would want. Above the screen's
/// number the saving is real; below it the photo has nothing left to give back.
const int photoLongEdgeCap = 2048;

/// JPEG quality for a re-encoded photo.
///
/// 85 is the point where a photograph stops paying for quality nobody can see.
/// 80 saves another 16% and looks the same on a phone; 85 is the safer of the
/// two on a screen that has not been invented yet, and the file is already
/// small.
const int photoJpegQuality = 85;

/// A photo brought inside the cap.
class CappedPhoto {
  const CappedPhoto({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}

/// The capped version of [bytes], or null when the photo should be left exactly
/// as it is.
///
/// Null covers three cases on purpose, because the caller does the same thing
/// in all of them: the photo is already inside the cap, the bytes are not an
/// image this app can re-encode, or the work failed. Leaving the file alone is
/// always a safe answer, so a failure here costs sharpness in the file listing
/// and never a photograph.
///
/// The size check reads the header and stops. A photo already inside the cap
/// costs a few dozen bytes of parsing and no decode, which is what makes the
/// startup pass cheap enough to run over a directory of photos that have
/// already been through it.
Future<CappedPhoto?> capPhoto(Uint8List bytes) async {
  if (!_isOverCap(bytes)) return null;

  try {
    // A 5 MB photograph is roughly a second of decode, resize and encode. On
    // the UI isolate that is a second of frozen sheet while the user waits for
    // a thumbnail, so the work goes somewhere else and the sheet keeps
    // animating.
    return await Isolate.run(() => capPhotoSynchronously(bytes));
  } catch (_) {
    return null;
  }
}

/// The same work, on whichever isolate calls it.
///
/// Public because a test should be able to prove the pixels without an isolate
/// in the way, and because [capPhoto] hands exactly this to the isolate it
/// spawns.
CappedPhoto? capPhotoSynchronously(Uint8List bytes) {
  final img.Encoder? encoder = _encoderFor(bytes);
  if (encoder == null) return null;

  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  // A phone held sideways writes the sensor's own landscape pixels and an EXIF
  // tag saying which way up to show them. Ignore the tag and the hiker comes
  // out lying down; rotate the pixels and leave the tag behind and the next
  // viewer turns them a second time.
  //
  // Checked rather than assumed, and the answer is worth writing down: this
  // package's JPEG decoder applies the tag and clears it as it reads, so a JPEG
  // is already upright by this line and this call changes nothing. Removing the
  // call broke no test, which is how that was found. It stays because nothing
  // promises the same of every decoder here, and because a reader should not
  // have to know that to see what the code intends.
  final img.Image upright = img.bakeOrientation(decoded);
  if (_longEdgeOf(upright.width, upright.height) <= photoLongEdgeCap) {
    return null;
  }

  final bool wide = upright.width >= upright.height;
  final img.Image resized = img.copyResize(
    upright,
    width: wide ? photoLongEdgeCap : null,
    height: wide ? null : photoLongEdgeCap,
    // A box filter, because this is a reduction. Cubic sharpening on the way
    // down puts halos on a ridge line against the sky.
    interpolation: img.Interpolation.average,
  );

  final Uint8List out = encoder.encode(resized);

  // A re-encode that came out bigger has cost the user space to gain nothing.
  // Rare, and it happens: a PNG of a screenshot resized to fewer, noisier
  // pixels can compress worse than the original did.
  if (out.length >= bytes.length) return null;

  return CappedPhoto(bytes: out, width: resized.width, height: resized.height);
}

/// True when the header says the long edge is over the cap.
///
/// False for anything that is not a decodable image, which is the same answer
/// the caller wants: leave it alone.
bool _isOverCap(Uint8List bytes) {
  try {
    final img.Decoder? decoder = img.findDecoderForData(bytes);
    if (decoder == null) return false;
    final img.DecodeInfo? info = decoder.startDecode(bytes);
    if (info == null) return false;
    // Orientation may swap the two, and the larger of them is the same number
    // either way, so the tag cannot change this answer.
    return _longEdgeOf(info.width, info.height) > photoLongEdgeCap;
  } catch (_) {
    return false;
  }
}

int _longEdgeOf(int width, int height) => math.max(width, height);

/// The encoder that writes the format [bytes] arrived in, or null when this app
/// will not re-encode it.
///
/// The format is kept rather than converted, and that is the decision that
/// keeps the database out of this ticket. What is stored against a climb is a
/// filename, extension and all. Turning a PNG into a JPEG would mean a new
/// name, which means rewriting rows, which means a migration that can leave a
/// row pointing at a file that is no longer there. Keeping the format means the
/// file is rewritten under its own name and nothing else in the app has to
/// know.
///
/// JPEG and PNG only. They are what a phone camera and a phone screenshot
/// produce. A GIF or a TIFF would re-encode into something larger than it
/// started, and the WebP a newer gallery might hand over has a decoder in this
/// package and no encoder, so all of them are left alone rather than damaged.
img.Encoder? _encoderFor(Uint8List bytes) =>
    switch (img.findFormatForData(bytes)) {
      img.ImageFormat.jpg => img.JpegEncoder(quality: photoJpegQuality),
      img.ImageFormat.png => img.PngEncoder(),
      _ => null,
    };
