/// The one rule that keeps climb photos findable: what gets stored is a bare
/// filename, and nothing else.
///
/// An absolute path saved today resolves perfectly today. The app container
/// directory changes between installs, so the same path resolves to nothing
/// later, and there is no error at save time to warn anybody. The photo is
/// still on disk; the app simply cannot say where. That is why the rule lives
/// in its own file with a test against it, rather than as a comment on the
/// column.
///
/// Two callers share it. [PhotoStore] generates names that pass it, and
/// `PhotoFilenamesConverter` refuses to write a value that does not, so the
/// only way into the column is through the rule.
library;

/// True when [value] names a file and nothing about where it lives.
///
/// Rejected, in order: nothing at all, a POSIX separator, a Windows separator,
/// the two directory entries that walk upwards, and a colon, which is how both
/// a Windows drive letter and a `file:` URL announce themselves. What survives
/// can only be joined onto a directory decided at render time.
bool isBarePhotoFilename(String value) {
  if (value.isEmpty) return false;
  if (value.contains('/')) return false;
  if (value.contains(r'\')) return false;
  if (value == '.' || value == '..') return false;
  if (value.contains(':')) return false;
  return true;
}
