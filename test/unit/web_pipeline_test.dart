import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secure_mark/utils/web_file_store.dart';
import 'package:secure_mark/watermark_processor.dart';

/// Web pipeline tests.
///
/// On web the engine has no virtual filesystem — every dart:io file
/// operation throws — so picked files are passed to the processor as
/// in-memory bytes ([WatermarkProcessor.processFile]'s `inputBytes`)
/// under synthetic paths that do not exist on disk. These tests run that
/// exact path on the VM: a nonexistent file plus real bytes must succeed.
void main() {
  group('WebFileStore', () {
    test('stores, retrieves and removes bytes by path', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      WebFileStore.put('/picked/1/a.jpg', bytes);
      expect(WebFileStore.bytesFor('/picked/1/a.jpg'), same(bytes));
      expect(WebFileStore.bytesFor('/picked/1/missing.jpg'), isNull);
      WebFileStore.remove('/picked/1/a.jpg');
      expect(WebFileStore.bytesFor('/picked/1/a.jpg'), isNull);
      WebFileStore.clear();
    });
  });

  group('processFile with in-memory bytes (web path)', () {
    test('processes a nonexistent file when bytes are provided', () async {
      final testImage = img.Image(width: 400, height: 300, numChannels: 4);
      testImage.clear(img.ColorRgba8(60, 120, 200, 255));
      final jpegBytes =
          Uint8List.fromList(img.encodeJpg(testImage, quality: 90));

      // Synthetic path like the web picker produces — no such file exists.
      final fakePath = '/picked/1234/test_photo.jpg';
      expect(await File(fakePath).exists(), isFalse);

      final result = await WatermarkProcessor.processFile(
        file: File(fakePath),
        inputBytes: jpegBytes,
        watermarkText: 'test',
        transparency: 0.5,
        density: 0.5,
        useRandomColor: false,
        selectedColorValue: 0xFF0000FF,
        fontSize: 20,
      );

      expect(result.outputBytes, isNotEmpty);
      expect(result.originalBytes, isNotNull);
      expect(result.originalBytes, hasLength(jpegBytes.length));
      expect(result.outputPath, contains('securemark-test_photo'));
    });

    test('still rejects missing bytes for a nonexistent file', () async {
      await expectLater(
        WatermarkProcessor.processFile(
          file: File('/picked/1234/ghost.jpg'),
          watermarkText: 'test',
          transparency: 0.5,
          density: 0.5,
          useRandomColor: false,
          selectedColorValue: 0xFF0000FF,
          fontSize: 20,
        ),
        throwsException,
      );
    });
  });
}
