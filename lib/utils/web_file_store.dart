import 'dart:typed_data';

/// In-memory file store for web builds.
///
/// The web engine no longer provides a virtual filesystem: every `dart:io`
/// file operation (create, read, write, exists) throws `UnsupportedError`
/// in the browser. Files picked on web therefore live here, keyed by the
/// synthetic paths the path-based pipeline already uses, and are released
/// on reset.
class WebFileStore {
  WebFileStore._();

  static final Map<String, Uint8List> _files = {};

  /// Stores [bytes] under [path].
  static void put(String path, Uint8List bytes) {
    _files[path] = bytes;
  }

  /// Returns the bytes stored under [path], if any.
  static Uint8List? bytesFor(String path) => _files[path];

  /// Removes [path] from the store.
  static void remove(String path) => _files.remove(path);

  /// Releases all stored bytes (e.g. on full reset).
  static void clear() => _files.clear();
}
