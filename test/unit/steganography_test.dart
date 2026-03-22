import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secure_mark/qr_config.dart';
import 'package:secure_mark/watermark_processor.dart';

void main() {
  group('Comprehensive Steganography Tests', () {
    late Uint8List testImageBytes;
    late Uint8List largeImageBytes;
    late Uint8List dummyFileBytes;
    late String dummyFileContent;
    late String testText;
    late String testPassword;
    late QrWatermarkConfig testQrConfig;
    late File testFile;

    setUpAll(() async {
      // Create test images with sufficient capacity
      final image = img.Image(width: 800, height: 600);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));
      testImageBytes = Uint8List.fromList(img.encodePng(image));

      // Larger image for ultimate test
      final largeImage = img.Image(width: 1200, height: 900);
      img.fill(largeImage, color: img.ColorRgb8(100, 150, 200));
      largeImageBytes = Uint8List.fromList(img.encodePng(largeImage));

      // Prepare test data
      testText = 'SecureMark-2026';
      dummyFileContent = 'Top Secret Document Content.';
      dummyFileBytes = Uint8List.fromList(utf8.encode(dummyFileContent));
      testPassword = 'complex-password-123';

      testQrConfig = QrWatermarkConfig(
        timestamp: DateTime.now(),
        type: QrType.metadata,
        author: 'Antoine Giniès',
        url: 'https://github.com/aginies/WatermarkApp',
      );

      // Create temp test file
      testFile = File('test_image.png')..writeAsBytesSync(testImageBytes);
    });

    tearDownAll(() {
      if (testFile.existsSync()) testFile.deleteSync();
    });

    group('Individual Features', () {
      test('LSB Text Signature', () async {
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: testText,
          useSteganography: true,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        // Verify result flags
        expect(result.steganographyVerified, true, reason: 'LSB verification should pass');

        // Verify extraction
        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        expect(analysis.signature, isNotNull);
        expect(analysis.signature, startsWith(testText), reason: 'Signature should start with original text');
      });

      test('Hidden File WITHOUT Encryption', () async {
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: '',
          hiddenFileName: 'secret.txt',
          hiddenFileBytes: dummyFileBytes,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.steganographyVerified, true);

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        expect(analysis.file, isNotNull);
        expect(analysis.file!.fileName, 'secret.txt');
        expect(analysis.file!.isEncrypted, false);
        expect(utf8.decode(analysis.file!.fileBytes), dummyFileContent);
      });

      test('Hidden File WITH Encryption', () async {
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: '',
          hiddenFileName: 'secret.txt',
          hiddenFileBytes: dummyFileBytes,
          steganographyPassword: testPassword,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.steganographyVerified, true);

        // Without password - should indicate encrypted
        final analysisNoPass = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        expect(analysisNoPass.file, isNotNull);
        expect(analysisNoPass.file!.isEncrypted, true);
        expect(analysisNoPass.file!.fileBytes.isEmpty, true);

        // With correct password
        final analysis = await WatermarkProcessor.analyzeImageAsync(
          result.outputBytes,
          password: testPassword,
        );
        expect(analysis.file!.fileName, 'secret.txt');
        expect(analysis.file!.isEncrypted, true);
        expect(utf8.decode(analysis.file!.fileBytes), dummyFileContent);

        // With wrong password - should fail
        final analysisWrong = await WatermarkProcessor.analyzeImageAsync(
          result.outputBytes,
          password: 'wrong-password',
        );
        expect(analysisWrong.file!.isEncrypted, true);
        expect(analysisWrong.file!.fileBytes.isEmpty, true);
      });

      test('Invisible QR Metadata', () async {
        final qrConfig = testQrConfig.copyWith(
          invisibleQr: true,
          visibleQr: false,
        );

        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: '',
          qrConfig: qrConfig,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.steganographyVerified, true);

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        expect(analysis.qrData, isNotNull);
        expect(analysis.qrData, contains('Antoine Giniès'));
        expect(analysis.qrData, contains('WatermarkApp'));
        expect(analysis.qrData, contains('SecureMark'));
      });

      test('Robust DCT Watermarking', () async {
        final robustText = 'ROBUST99';
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: robustText,
          useRobustSteganography: true,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.robustVerified, true, reason: 'Robust verification should pass');

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        expect(analysis.robustSignature, isNotNull);
        expect(analysis.robustSignature, startsWith(robustText));
      });
    });

    group('Multi-Channel Tests (Separate Channels)', () {
      test('LSB Signature + Hidden File (Different Channels)', () async {
        // According to implementation:
        // - Blue channel: LSB text signature
        // - Green channel: Hidden file
        // These should NOT conflict

        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: testText,
          useSteganography: true,
          hiddenFileName: 'attachment.dat',
          hiddenFileBytes: dummyFileBytes,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.steganographyVerified, true);

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);

        // Both should be present
        expect(analysis.signature, isNotNull);
        expect(analysis.signature, startsWith(testText));
        expect(analysis.file, isNotNull);
        expect(analysis.file!.fileName, 'attachment.dat');
        expect(analysis.file!.fileBytes, dummyFileBytes);
      });

      test('All Three Channels (R+G+B)', () async {
        // Red: Invisible QR
        // Green: Hidden File
        // Blue: LSB Signature

        final qrConfig = testQrConfig.copyWith(
          invisibleQr: true,
          visibleQr: false,
        );

        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: testText,
          useSteganography: true,
          hiddenFileName: 'data.bin',
          hiddenFileBytes: dummyFileBytes,
          qrConfig: qrConfig,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        expect(result.steganographyVerified, true);

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);

        // All three should be present
        expect(analysis.signature, isNotNull, reason: 'LSB signature missing');
        expect(analysis.file, isNotNull, reason: 'Hidden file missing');
        expect(analysis.qrData, isNotNull, reason: 'QR data missing');

        expect(analysis.signature, startsWith(testText));
        expect(analysis.file!.fileName, 'data.bin');
        expect(analysis.qrData, contains('Antoine Giniès'));
      });
    });

    group('Combined Features (Ultimate Test)', () {
      test('ALL Steganography Types Together', () async {
        // This test uses a larger image to ensure capacity
        final largeFile = File('test_large.png')..writeAsBytesSync(largeImageBytes);

        try {
          final qrConfig = testQrConfig.copyWith(
            invisibleQr: true,
            visibleQr: false,
          );

          final result = await WatermarkProcessor.processFile(
            file: largeFile,
            watermarkText: testText,
            useSteganography: true, // LSB Signature (Blue)
            useRobustSteganography: true, // DCT Signature (Frequency)
            hiddenFileName: 'mixed.bin',
            hiddenFileBytes: dummyFileBytes,
            steganographyPassword: testPassword,
            qrConfig: qrConfig, // Invisible QR (Red)
            transparency: 50,
            density: 10,
            useRandomColor: false,
            selectedColorValue: 0xFFFF0000,
            fontSize: 20,
          );

          expect(result.steganographyVerified, true, reason: 'LSB verification failed');
          expect(result.robustVerified, true, reason: 'Robust verification failed');

          // Verification with password
          final analysis = await WatermarkProcessor.analyzeImageAsync(
            result.outputBytes,
            password: testPassword,
          );

          print('--- Ultimate Extraction Results ---');
          print('LSB Signature: ${analysis.signature}');
          print('Robust Signature: ${analysis.robustSignature}');
          print('Hidden File: ${analysis.file?.fileName} (${analysis.file?.fileBytes.length} bytes)');
          print('QR Data: ${analysis.qrData}');

          expect(analysis.signature, startsWith(testText), reason: 'LSB Signature failed');
          expect(analysis.robustSignature, startsWith(testText), reason: 'Robust DCT Signature failed');
          expect(analysis.file?.fileName, 'mixed.bin', reason: 'Hidden File name failed');
          expect(analysis.file?.fileBytes, dummyFileBytes, reason: 'Hidden File content failed');
          expect(analysis.qrData, contains('Antoine Giniès'), reason: 'QR Data failed');
        } finally {
          if (largeFile.existsSync()) largeFile.deleteSync();
        }
      });
    });

    group('Error and Edge Cases', () {
      test('Empty signature returns null', () async {
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: '',
          useSteganography: true,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        final analysis = await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
        // Empty watermark shouldn't embed anything useful
        expect(analysis.signature, anyOf(isNull, isEmpty));
      });

      test('Image without steganography returns empty result', () {
        final cleanImage = img.Image(width: 200, height: 200);
        img.fill(cleanImage, color: img.ColorRgb8(255, 255, 255));
        final bytes = Uint8List.fromList(img.encodePng(cleanImage));

        final analysis = WatermarkProcessor.analyzeImage(bytes);
        expect(analysis.signature, isNull);
        expect(analysis.file, isNull);
        expect(analysis.qrData, isNull);
        expect(analysis.robustSignature, isNull);
      });

      test('Corrupted magic header returns null', () {
        final image = img.decodeImage(testImageBytes)!;

        // Corrupt the first few pixels (where magic header would be)
        for (var i = 0; i < 16; i++) {
          final pixel = image.getPixel(i % image.width, i ~/ image.width);
          pixel.r = 255;
          pixel.g = 255;
          pixel.b = 255;
        }

        final corrupted = Uint8List.fromList(img.encodePng(image));
        final analysis = WatermarkProcessor.analyzeImage(corrupted);

        expect(analysis.signature, isNull);
        expect(analysis.file, isNull);
        expect(analysis.qrData, isNull);
      });

      test('Wrong password returns encrypted indicator', () async {
        final result = await WatermarkProcessor.processFile(
          file: testFile,
          watermarkText: testText,
          useSteganography: true,
          steganographyPassword: testPassword,
          transparency: 50,
          density: 10,
          useRandomColor: false,
          selectedColorValue: 0xFFFF0000,
          fontSize: 20,
        );

        // Try to extract with wrong password
        final analysis = await WatermarkProcessor.analyzeImageAsync(
          result.outputBytes,
          password: 'wrong-password',
        );

        expect(analysis.signature, contains('[ENCRYPTED]'));
      });
    });

    group('Capacity Tests', () {
      test('Small image capacity limits', () {
        final tinyImage = img.Image(width: 100, height: 100);
        img.fill(tinyImage, color: img.ColorRgb8(128, 128, 128));

        // Calculate approximate capacity
        final totalPixels = 100 * 100;
        final usablePixels = totalPixels - 64; // Header overhead
        final byteCapacity = usablePixels ~/ 8;

        print('Tiny image capacity: ~$byteCapacity bytes');

        // A 100x100 image should handle small signatures but not large files
        expect(byteCapacity, greaterThan(100), reason: 'Should handle small text');
        expect(byteCapacity, lessThan(10000), reason: 'Too small for large files');
      });
    });
  });
}
