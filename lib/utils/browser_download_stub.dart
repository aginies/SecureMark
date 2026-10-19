import 'dart:typed_data';

/// Non-web placeholder: browser downloads only exist on the web. Callers must
/// guard with `kIsWeb`; on other platforms the output flows through the share
/// sheet or the local server instead.
void browserDownload(Uint8List bytes, String fileName, String mimeType) {
  throw UnsupportedError('Browser downloads are only available on the web');
}
