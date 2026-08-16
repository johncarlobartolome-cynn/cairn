import 'package:cairn/data/photos/photo_filename.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rule that decides whether a photo is findable after the next install.
///
/// A path stored today resolves today and resolves to nothing later, with no
/// error either time. So the rule is a function with a test, not a comment.
void main() {
  group('a bare filename passes', () {
    for (final String name in <String>[
      'climb_1755300000000000_a3f9c2d1.jpg',
      'photo.png',
      'no-extension',
      'spaces are allowed.jpeg',
      'ünïcode.heic',
    ]) {
      test(name, () => expect(isBarePhotoFilename(name), isTrue));
    }
  });

  group('anything saying where a file lives is refused', () {
    const Map<String, String> refused = <String, String>{
      '': 'nothing at all',
      '/data/user/0/com.cynnlabs.cairn/app_flutter/climb.jpg':
          'the absolute path the picker era would have stored',
      'app_flutter/climb.jpg': 'a directory in front of the name',
      'climb.jpg/': 'a trailing separator',
      '/': 'the root itself',
      '../climb.jpg': 'a walk upwards',
      '.': 'this directory',
      '..': 'the one above',
      r'C:\photos\climb.jpg': 'a Windows path',
      r'photos\climb.jpg': 'a Windows separator on its own',
      'file:///tmp/climb.jpg': 'a URL wearing a filename',
      'C:climb.jpg': 'a drive letter with no separator after it',
    };

    refused.forEach((String value, String why) {
      test(why, () => expect(isBarePhotoFilename(value), isFalse));
    });
  });
}
