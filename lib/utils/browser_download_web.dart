import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Triggers a browser download of [bytes] as [fileName].
void browserDownload(Uint8List bytes, String fileName, String mimeType) {
  // Blob takes JS parts: hand over the underlying buffer (a cast in JS,
  // a clone in Wasm). Copy first if the list is a sub-view of a larger
  // buffer.
  final buffer = (bytes.offsetInBytes == 0 &&
          bytes.lengthInBytes == bytes.buffer.lengthInBytes)
      ? bytes.buffer
      : Uint8List.fromList(bytes).buffer;
  final parts = JSArray<web.BlobPart>();
  // toJS requires SDK 3.10+; web builds use the current SDK, and raising
  // the package floor to 3.10 would switch dart format to the tall style
  // across the whole repo.
  // ignore: sdk_version_since
  parts.add(buffer.toJS);
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Let the browser start the download before releasing the blob URL.
  Future.delayed(
      const Duration(seconds: 10), () => web.URL.revokeObjectURL(url));
}
