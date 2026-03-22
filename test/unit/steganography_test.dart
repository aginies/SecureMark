import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/qr_config.dart';
import 'package:secure_mark/watermark_processor.dart';

void main() {
  group('Comprehensive Steganography Tests with app.jpg', () {
    late Uint8List dummyFileBytes;
    late String dummyFileContent;
    late String testText;
    late String testPassword;
    late QrWatermarkConfig testQrConfig;
    late File appJpgCopy;

    setUpAll(() async {
      // Copy app.jpg for testing
      final File originalAppJpg = File('app.jpg');
      if (!await originalAppJpg.exists()) {
        throw Exception(
            'app.jpg not found! Please ensure it exists in the root directory.');
      }

      appJpgCopy = File('app_test_copy.jpg');
      await originalAppJpg.copy(appJpgCopy.path);

      // Prepare test data
      testText = 'SecureMark-Test';
      dummyFileContent = 'This is a test file for steganography.';
      dummyFileBytes = Uint8List.fromList(utf8.encode(dummyFileContent));
      testPassword = 'test-password-2026';

      testQrConfig = QrWatermarkConfig(
        timestamp: DateTime.now(),
        type: QrType.metadata,
        author: 'Antoine Giniès',
        url: 'https://github.com/aginies/WatermarkApp',
      );
    });

    tearDownAll(() async {
      if (await appJpgCopy.exists()) {
        await appJpgCopy.delete();
      }
      // Clean up any generated output files if they exist in the current dir
      // (processFile usually saves them near the source)
    });

    test(
        'Ultimate Scenario: ALL TOGETHER (LSB Signature + Robust DCT + Hidden File + QR)',
        () async {
      final result = await WatermarkProcessor.processFile(
        file: appJpgCopy,
        watermarkText: testText,
        useSteganography: true, // For LSB Signature & File
        useRobustSteganography: true, // For DCT Signature
        hiddenFileName: 'test_hidden.txt',
        hiddenFileBytes: dummyFileBytes,
        steganographyPassword: testPassword,
        qrConfig: testQrConfig.copyWith(invisibleQr: true),
        transparency: 50,
        density: 15,
        useRandomColor: true,
        selectedColorValue: 0xFFFF0000,
        fontSize: 24,
      );

      // 1. Verify internal verification flags in ProcessResult
      expect(result.steganographyVerified, true,
          reason: 'LSB/File/QR verification failed during processing');
      expect(result.robustVerified, true,
          reason: 'Robust DCT verification failed during processing');

      // 2. Perform manual extraction for deeper verification
      final analysis = await WatermarkProcessor.analyzeImageAsync(
        result.outputBytes,
        password: testPassword,
      );

      expect(analysis.signature, startsWith(testText),
          reason: 'LSB Signature extraction mismatch');
      expect(analysis.robustSignature, startsWith(testText),
          reason: 'Robust DCT Signature extraction mismatch');
      expect(analysis.file?.fileName, 'test_hidden.txt',
          reason: 'Hidden File name mismatch');
      expect(utf8.decode(analysis.file!.fileBytes), dummyFileContent,
          reason: 'Hidden File content mismatch');
      expect(analysis.qrData, contains('Antoine Giniès'),
          reason: 'QR Metadata extraction mismatch');
    });

    test('Scenario: Only Robust Watermark', () async {
      final result = await WatermarkProcessor.processFile(
        file: appJpgCopy,
        watermarkText: 'ROBUST-ONLY',
        useRobustSteganography: true,
        useSteganography: false,
        transparency: 100, // invisible visual watermark
        density: 0,
        useRandomColor: false,
        selectedColorValue: 0,
        fontSize: 20,
      );

      expect(result.robustVerified, true);

      final analysis =
          await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
      expect(analysis.robustSignature, startsWith('ROBUST-ONLY'));
      expect(analysis.signature, isNull,
          reason: 'LSB signature should NOT be present');
    });

    test('Scenario: Only Hidden File (LSB)', () async {
      final result = await WatermarkProcessor.processFile(
        file: appJpgCopy,
        watermarkText: '',
        useSteganography: true,
        hiddenFileName: 'only_file.dat',
        hiddenFileBytes: dummyFileBytes,
        transparency: 100,
        density: 0,
        useRandomColor: false,
        selectedColorValue: 0,
        fontSize: 20,
      );

      expect(result.steganographyVerified, true);

      final analysis =
          await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
      expect(analysis.file?.fileName, 'only_file.dat');
      expect(analysis.file?.fileBytes, dummyFileBytes);
      expect(analysis.signature, isNotNull,
          reason:
              'LSB Signature always contains at least a timestamp if useSteganography is true');
    });

    test('Scenario: Hidden File + Invisible QR', () async {
      final result = await WatermarkProcessor.processFile(
        file: appJpgCopy,
        watermarkText: '',
        useSteganography: true,
        hiddenFileName: 'combined.zip',
        hiddenFileBytes: dummyFileBytes,
        qrConfig: testQrConfig.copyWith(invisibleQr: true),
        transparency: 100,
        density: 0,
        useRandomColor: false,
        selectedColorValue: 0,
        fontSize: 20,
      );

      expect(result.steganographyVerified, true);

      final analysis =
          await WatermarkProcessor.analyzeImageAsync(result.outputBytes);
      expect(analysis.file?.fileName, 'combined.zip');
      expect(analysis.file?.fileBytes, dummyFileBytes);
      expect(analysis.qrData, contains('Antoine Giniès'));
    });
  });
}
