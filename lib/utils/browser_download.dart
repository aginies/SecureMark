/// Platform-conditional browser download.
///
/// The web implementation uses `package:web`, which imports `dart:js_interop`
/// and therefore cannot be compiled for the VM (widget tests, native builds).
library;

export 'browser_download_stub.dart'
    if (dart.library.js_interop) 'browser_download_web.dart';
