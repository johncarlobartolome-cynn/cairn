import 'package:image_picker/image_picker.dart';

/// Where a photo comes from before Cairn owns a copy of it.
///
/// An interface rather than a direct call to `image_picker`, for one reason:
/// the system picker is another process, and no test on a device or on the host
/// can tap it. Everything that happens after the pick is Cairn's own work and
/// has to be provable, so the plugin sits behind a seam and a test supplies the
/// paths the picker would have returned.
abstract interface class PhotoPicker {
  /// The paths of the images the user chose, in the order they chose them.
  ///
  /// Empty when the picker was dismissed without choosing anything, which is a
  /// normal answer rather than a failure.
  ///
  /// Every path points at a file the OS may reclaim at any time. Copy what you
  /// intend to keep before you rely on it.
  Future<List<String>> pick();
}

/// The real one: the system photo picker, several photos at a time.
///
/// Gallery only, no camera. On Android 13 and up `pickMultiImage` goes through
/// the system photo picker, which hands over only the files the user chose and
/// needs no storage permission and no manifest entry. Adding the camera would
/// mean a permission prompt and a refusal path to design, and the ticket is
/// about not losing the photo once it is picked.
class SystemPhotoPicker implements PhotoPicker {
  const SystemPhotoPicker();

  @override
  Future<List<String>> pick() async {
    final List<XFile> picked = await ImagePicker().pickMultiImage();
    return <String>[for (final XFile file in picked) file.path];
  }
}
