// Checks the generated iOS icon set: every slot Contents.json names exists, is
// the pixel size that slot asks for, and carries no alpha channel.
//
// **Why this exists.** App Store Connect rejects an icon with an alpha channel,
// and it does so at upload, long after anybody looked at the icon. The failure
// is invisible on a simulator, where a transparent icon just renders black
// behind the glyph. So the guarantee is checked by a command instead of by
// memory, and tool/icons.sh runs it every time it regenerates.
//
// Not part of `flutter test`: it reads generated files rather than app code, and
// the unit suite has a fixed count that a platform check has no business
// joining.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;

const String _appIconSet = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';

void main() {
  final dir = Directory('${Directory.current.path}/$_appIconSet');
  if (!dir.existsSync()) {
    _fail('no icon set at $_appIconSet');
  }

  final manifest =
      jsonDecode(File('${dir.path}/Contents.json').readAsStringSync())
          as Map<String, dynamic>;
  final images = (manifest['images'] as List<dynamic>)
      .cast<Map<String, dynamic>>();

  final problems = <String>[];
  var checked = 0;

  for (final entry in images) {
    final name = entry['filename'] as String?;
    if (name == null) {
      continue;
    }

    final file = File('${dir.path}/$name');
    if (!file.existsSync()) {
      problems.add('$name is named by Contents.json but is not there');
      continue;
    }

    final image = img.decodePng(file.readAsBytesSync());
    if (image == null) {
      problems.add('$name did not decode as a PNG');
      continue;
    }

    final scale = int.parse((entry['scale'] as String).replaceAll('x', ''));
    final points = double.parse((entry['size'] as String).split('x').first);
    final expected = (points * scale).round();
    if (image.width != expected || image.height != expected) {
      problems.add(
        '$name is ${image.width}x${image.height}, '
        'the ${entry['size']} @${scale}x slot needs ${expected}x$expected',
      );
    }
    if (image.hasAlpha) {
      problems.add('$name has an alpha channel, which the App Store rejects');
    }

    checked++;
  }

  if (problems.isEmpty) {
    stdout.writeln('$checked iOS icons: right size, no alpha channel');
    return;
  }

  for (final problem in problems) {
    stderr.writeln('  $problem');
  }
  _fail('${problems.length} problem(s) in the iOS icon set');
}

Never _fail(String message) {
  stderr.writeln('check_ios_opaque: $message');
  exit(1);
}
