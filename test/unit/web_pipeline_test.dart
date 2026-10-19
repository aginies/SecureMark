import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:secure_mark/utils/web_file_store.dart';
import 'package:secure_mark/watermark_processor.dart';

// SharedPreferences (used by IdentityManager) needs a binding in tests.
void _ensureBinding() => TestWidgetsFlutterBinding.ensureInitialized();

/// Web pipeline tests.
///
/// On web the engine has no virtual filesystem — every dart:io file
/// operation throws — so picked files are passed to the processor as
/// in-memory bytes ([WatermarkProcessor.processFile]'s `inputBytes`)
/// under synthetic paths that do not exist on disk. These tests run that
/// exact path on the VM: a nonexistent file plus real bytes must succeed.
void main() {
  _ensureBinding();

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

    // The web build runs the same processor code in a browser worker; these
    // combinations pin the full feature matrix on the in-memory-bytes path so
    // any regression surfaces on the VM before it reaches the browser.
    // Real photo content (not a flat synthetic image) because DCT capacity
    // and verification need coefficient variance.
    late Uint8List photoBytes;
    setUpAll(() async {
      photoBytes =
          Uint8List.fromList(await File('images/app.jpg').readAsBytes());
    });

    test('text + steganography + password', () async {
      final result = await WatermarkProcessor.processFile(
        file: File('/picked/1234/stego.jpg'),
        inputBytes: photoBytes,
        watermarkText: 'confidential',
        transparency: 0.5,
        density: 0.5,
        useRandomColor: false,
        selectedColorValue: 0xFF0000FF,
        fontSize: 20,
        useSteganography: true,
        steganographyPassword: 'secret',
        steganographyText: 'my signature',
        // LSB stego only survives lossless output — JPEG re-encoding
        // destroys the embedded bits (robust DCT is the JPEG path).
        forcePng: true,
      );

      expect(result.outputBytes, isNotEmpty);
      expect(result.steganographyVerified, isTrue);
    });

    test('text + robust steganography', () async {
      final result = await WatermarkProcessor.processFile(
        file: File('/picked/1234/robust.jpg'),
        inputBytes: photoBytes,
        watermarkText: 'confidential',
        transparency: 0.5,
        density: 0.5,
        useRandomColor: false,
        selectedColorValue: 0xFF0000FF,
        fontSize: 20,
        useRobustSteganography: true,
        steganographyText: 'my signature',
      );

      expect(result.outputBytes, isNotEmpty);
    });

    test('text + AI cloaking + digital signature', () async {
      SharedPreferences.setMockInitialValues({});

      final result = await WatermarkProcessor.processFile(
        file: File('/picked/1234/cloak.jpg'),
        inputBytes: photoBytes,
        watermarkText: 'confidential',
        transparency: 0.5,
        density: 0.5,
        useRandomColor: false,
        selectedColorValue: 0xFF0000FF,
        fontSize: 20,
        useAiCloaking: true,
        digitallySign: true,
      );

      expect(result.outputBytes, isNotEmpty);
    });
  });
}
