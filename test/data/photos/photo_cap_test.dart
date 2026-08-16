import 'dart:typed_data';

import 'package:cairn/data/photos/photo_cap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../helpers/photo_fixtures.dart';

/// The cap itself: bytes in, smaller bytes out, and the three ways that can go
/// wrong quietly.
void main() {
  img.Image decode(Uint8List bytes) => img.decodeImage(bytes)!;

  group('a photo over the cap', () {
    test('comes back with its long edge on the cap', () async {
      final Uint8List big = photographBytes(width: 3000, height: 2000);

      final CappedPhoto capped = (await capPhoto(big))!;

      expect(capped.width, photoLongEdgeCap);
      expect(capped.height, 1365);
      expect(capped.bytes.length, lessThan(big.length));
    });

    test('is capped on its long edge whichever way up it is', () async {
      final Uint8List tall = photographBytes(width: 2000, height: 3000);

      final CappedPhoto capped = (await capPhoto(tall))!;

      expect(capped.height, photoLongEdgeCap);
      expect(capped.width, 1365);
    });

    test('is still the format it arrived in', () async {
      final Uint8List jpeg = photographBytes(width: 3000, height: 2000);
      final Uint8List png = photographBytes(
        width: 3000,
        height: 2000,
        png: true,
      );

      expect(
        img.findFormatForData((await capPhoto(jpeg))!.bytes),
        img.ImageFormat.jpg,
      );
      expect(
        img.findFormatForData((await capPhoto(png))!.bytes),
        img.ImageFormat.png,
      );
    });

    test('is still the same picture', () async {
      // The corner mark is where it was, and the ground is not red. A resize
      // that returned an empty frame or a differently cropped one would pass a
      // size assertion and fail this.
      final Uint8List big = photographBytes(width: 3000, height: 2000);

      final img.Image out = decode((await capPhoto(big))!.bytes);

      expect(isCornerMark(out, 40, 40), isTrue);
      expect(isCornerMark(out, out.width - 40, out.height - 40), isFalse);
    });
  });

  group('a photo inside the cap', () {
    test('is left alone rather than re-encoded', () async {
      final Uint8List small = photographBytes(width: 800, height: 600);

      expect(await capPhoto(small), isNull);
    });

    test('is left alone at exactly the cap', () async {
      final Uint8List edge = photographBytes(
        width: photoLongEdgeCap,
        height: 1200,
      );

      expect(await capPhoto(edge), isNull);
    });

    test('is never made bigger', () async {
      // The rule stated the other way round, because the resize call takes a
      // target and would happily upscale to it.
      final Uint8List small = photographBytes(width: 320, height: 240);

      expect(await capPhoto(small), isNull);
    });
  });

  group('orientation', () {
    test('a sideways photo comes out upright', () async {
      // The classic way a downscale turns everyone sideways. The pixels are
      // landscape and the EXIF tag says to show them a quarter turn clockwise,
      // so the corner mark belongs in the top right of the result and the
      // result belongs on its end.
      final Uint8List sideways = photographBytes(
        width: 3000,
        height: 2000,
        orientation: 6,
      );

      final CappedPhoto capped = (await capPhoto(sideways))!;
      final img.Image out = decode(capped.bytes);

      expect(out.height, greaterThan(out.width), reason: 'should be portrait');
      expect(capped.height, photoLongEdgeCap);
      expect(isCornerMark(out, out.width - 40, 40), isTrue);
      expect(isCornerMark(out, 40, 40), isFalse);
    });

    test('nothing is left telling a viewer to turn it again', () async {
      // The other half of the trap. Rotating the pixels and leaving the tag
      // behind turns the photo twice in the next thing that reads EXIF, and
      // the file would still be the right number of bytes and the right shape
      // on the way out of here.
      //
      // The stored size is the pixels as they sit in the file; the decoded
      // size is those pixels after any tag has been applied. Equal means there
      // is nothing left to apply.
      final Uint8List sideways = photographBytes(
        width: 3000,
        height: 2000,
        orientation: 6,
      );
      expect(
        storedSizeOf(sideways),
        '3000x2000',
        reason:
            'the fixture has to be a real sideways photo or this proves '
            'nothing',
      );

      final CappedPhoto capped = (await capPhoto(sideways))!;
      final img.Image out = decode(capped.bytes);

      expect(storedSizeOf(capped.bytes), '${capped.width}x${capped.height}');
      expect('${out.width}x${out.height}', '${capped.width}x${capped.height}');
    });

    test('an upright photo is not turned', () async {
      final Uint8List upright = photographBytes(width: 3000, height: 2000);

      final img.Image out = decode((await capPhoto(upright))!.bytes);

      expect(out.width, greaterThan(out.height));
      expect(isCornerMark(out, 40, 40), isTrue);
    });
  });

  group('anything the cap cannot read', () {
    test('bytes that are not an image are left alone', () async {
      expect(
        await capPhoto(Uint8List.fromList(List<int>.filled(64, 7))),
        isNull,
      );
    });

    test('an empty file is left alone', () async {
      expect(await capPhoto(Uint8List(0)), isNull);
    });

    test('a truncated photo is left alone rather than half decoded', () async {
      final Uint8List big = photographBytes(width: 3000, height: 2000);
      // Header intact, so the size check says it is over the cap and the decode
      // is the thing that has to fail safely.
      final Uint8List cut = Uint8List.sublistView(big, 0, 2000);

      expect(await capPhoto(cut), isNull);
    });

    test('a format with no encoder here is left alone', () async {
      // A GIF decodes in this package and re-encodes worse than it arrived, so
      // the cap declines rather than damaging it.
      final img.Image frame = img.Image(width: 3000, height: 2000);
      final Uint8List gif = img.encodeGif(frame);

      expect(await capPhoto(gif), isNull);
    });
  });

  test('the same work off the isolate gives the same answer', () async {
    // capPhoto hands exactly this to the isolate it spawns, so the two have to
    // agree or the isolate is doing something the tests never see.
    final Uint8List big = photographBytes(width: 3000, height: 2000);

    final CappedPhoto onIsolate = (await capPhoto(big))!;
    final CappedPhoto here = capPhotoSynchronously(big)!;

    expect(onIsolate.width, here.width);
    expect(onIsolate.height, here.height);
    expect(onIsolate.bytes, here.bytes);
  });
}
