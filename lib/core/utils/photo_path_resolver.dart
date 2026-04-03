import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves photo file paths between relative (stored in DB) and absolute
/// (needed by Image.file).
///
/// On iOS, the app sandbox container UUID changes on every Xcode rebuild /
/// reinstall, which invalidates absolute paths stored in the database. This
/// class stores only relative paths (e.g. `photos/<uuid>.jpg`) and resolves
/// them to absolute paths at runtime using [getApplicationDocumentsDirectory].
class PhotoPathResolver {
  PhotoPathResolver._();
  static final instance = PhotoPathResolver._();

  String? _documentsPath;

  /// Initialise (call once at app startup or lazily on first use).
  Future<void> init() async {
    _documentsPath ??= (await getApplicationDocumentsDirectory()).path;
  }

  /// Returns the cached documents directory path.
  /// Throws if [init] hasn't been called yet — but [resolve] calls it lazily.
  String get documentsPath {
    assert(
      _documentsPath != null,
      'PhotoPathResolver.init() must be called before accessing documentsPath',
    );
    return _documentsPath!;
  }

  /// Convert an absolute destination path to a relative path for DB storage.
  ///
  /// Example: `/var/.../Documents/photos/abc.jpg` → `photos/abc.jpg`
  String toRelative(String absolutePath) {
    if (_documentsPath != null && absolutePath.startsWith(_documentsPath!)) {
      // Strip the documents directory prefix (and the trailing separator)
      final relative = absolutePath.substring(_documentsPath!.length);
      // Remove leading separator if present
      return relative.startsWith(p.separator)
          ? relative.substring(1)
          : relative;
    }
    // If it's already relative or doesn't start with documents dir, try to
    // extract just the `photos/...` portion.
    final photosIndex = absolutePath.indexOf('photos${p.separator}');
    if (photosIndex >= 0) {
      return absolutePath.substring(photosIndex);
    }
    // Last resort: return as-is (already relative)
    return absolutePath;
  }

  /// Resolve a (possibly relative) file path to an absolute path.
  ///
  /// If the path is already absolute, checks whether the file exists. If not,
  /// tries to extract the relative portion and resolve it against the current
  /// documents directory. This handles the case where a previously-stored
  /// absolute path is stale due to sandbox UUID change.
  String resolve(String storedPath) {
    if (_documentsPath == null) {
      // Fallback: return as-is (init hasn't been called — shouldn't happen)
      return storedPath;
    }

    // Already absolute and under current documents dir — use directly
    if (storedPath.startsWith(_documentsPath!)) {
      return storedPath;
    }

    // Relative path (e.g. `photos/abc.jpg`) — resolve against documents dir
    if (!p.isAbsolute(storedPath)) {
      return p.join(_documentsPath!, storedPath);
    }

    // Absolute but under a DIFFERENT (stale) documents dir.
    // Extract the relative `photos/...` tail and resolve against current dir.
    final photosIndex = storedPath.indexOf('photos${p.separator}');
    if (photosIndex >= 0) {
      final relative = storedPath.substring(photosIndex);
      return p.join(_documentsPath!, relative);
    }

    // Can't resolve — return as-is
    return storedPath;
  }

  /// Convenience: resolve and return a [File].
  File resolveFile(String storedPath) => File(resolve(storedPath));
}
