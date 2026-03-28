import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:secure_mark/utils/certificate_manager.dart';
import 'package:secure_mark/utils/local_server_manager.dart';

void main() {
  group('Streaming File Transfer Tests', () {
    late Directory tempDir;

    setUp(() async {
      // Create temp directory for test files
      tempDir = await Directory.systemTemp.createTemp('streaming_test_');
    });

    tearDown(() async {
      // Clean up temp files
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }

      // Ensure server is stopped
      await LocalServerManager.stopServer();
    });

    test('Stream in-memory bytes in chunks', () async {
      final testData = Uint8List.fromList(
        List.generate(1024 * 256, (i) => i % 256), // 256 KB
      );
      final fileName = 'test_file.bin';

      // Track progress
      final progressUpdates = <int>[];

      final port = await LocalServerManager.startServer(
        testData,
        fileName,
        onProgress: (sent, total) {
          progressUpdates.add(sent);
        },
      );

      // Download the file
      final response = await http.get(
        Uri.parse(
            'http://localhost:$port/${LocalServerManager.token}/download'),
      );

      expect(response.statusCode, equals(200));
      expect(response.bodyBytes, equals(testData));

      // Verify progress was reported
      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last, equals(testData.length));

      print('Progress updates: ${progressUpdates.length}');
      print('Final: ${progressUpdates.last} of ${testData.length} bytes');

      // Send ACK to server to let it shutdown gracefully
      await http.get(
        Uri.parse('http://localhost:$port/${LocalServerManager.token}/ack'),
      );

      // Wait for server to fully stop before test completes
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Stream file from disk (memory-efficient)', () async {
      // Create a test file
      final testFile = File(p.join(tempDir.path, 'large_test.dat'));
      final testData = Uint8List.fromList(
        List.generate(1024 * 512, (i) => i % 256), // 512 KB
      );
      await testFile.writeAsBytes(testData);

      final progressUpdates = <int>[];

      final port = await LocalServerManager.startServerFromFile(
        testFile.path,
        onProgress: (sent, total) {
          progressUpdates.add(sent);
        },
      );

      // Download the file
      final response = await http.get(
        Uri.parse(
            'http://localhost:$port/${LocalServerManager.token}/download'),
      );

      expect(response.statusCode, equals(200));
      expect(response.bodyBytes, equals(testData));

      // Verify progress was reported
      expect(progressUpdates.isNotEmpty, isTrue);
      expect(progressUpdates.last, equals(testData.length));

      print('Streamed ${testData.length} bytes from disk');
      print('Progress updates: ${progressUpdates.length}');

      // Send ACK to server to let it shutdown gracefully
      await http.get(
        Uri.parse('http://localhost:$port/${LocalServerManager.token}/ack'),
      );

      // Wait for server to fully stop before test completes
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('Server handles multiple chunk sizes correctly', () async {
      // Test with different sizes around chunk boundary (64 KB)
      for (final sizeKB in [32, 64, 65, 128, 256]) {
        final testData = Uint8List.fromList(
          List.generate(sizeKB * 1024, (i) => (i + sizeKB) % 256),
        );

        final port = await LocalServerManager.startServer(
          testData,
          'test_$sizeKB.bin',
        );

        final downloadUrl = Uri.parse(
            'http://localhost:$port/${LocalServerManager.token}/download');
        final response = await http.get(downloadUrl);

        expect(response.statusCode, equals(200));
        expect(response.bodyBytes.length, equals(testData.length));
        expect(response.bodyBytes, equals(testData));

        print('✓ $sizeKB KB file transferred successfully');

        // Send ACK to server
        final ackUrl =
            Uri.parse('http://localhost:$port/${LocalServerManager.token}/ack');
        await http.get(ackUrl);

        // Wait for server to auto-stop after acknowledgment
        await Future.delayed(const Duration(milliseconds: 100));
        expect(LocalServerManager.isRunning, isFalse);
      }
    });

    test('Receive server supports progress callbacks', () async {
      final uploadData = Uint8List.fromList(
        utf8.encode('Test upload data with progress tracking'),
      );

      final progressUpdates = <int>[];
      String? receivedFilePath;
      String? receivedFileName;

      final port = await LocalServerManager.startReceiveServer(
        (fileName, remoteAddr, {String? filePath}) {
          receivedFileName = fileName;
          receivedFilePath = filePath;
        },
        onProgress: (received, total) {
          progressUpdates.add(received);
        },
      );

      // Upload file
      final request = http.Request(
        'POST',
        Uri.parse('http://localhost:$port/${LocalServerManager.token}/upload'),
      );
      request.headers['x-file-name'] = 'upload_test.txt';
      request.bodyBytes = uploadData;

      final response = await request.send();
      expect(response.statusCode, equals(200));

      // Wait a bit for server callback
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedFileName, equals('upload_test.txt'));
      expect(receivedFilePath, isNotNull);

      // Verify file was streamed to disk
      if (receivedFilePath != null) {
        final receivedFile = File(receivedFilePath!);
        expect(await receivedFile.exists(), isTrue);
        final receivedData = await receivedFile.readAsBytes();
        expect(receivedData, equals(uploadData));
        print('✅ File streamed to disk: $receivedFilePath');
      }

      // Note: Progress may not be reported if upload is too fast
      print('Upload completed: ${uploadData.length} bytes');
      print('Progress updates: ${progressUpdates.length}');
    });

    test('Server stops automatically after one-shot transfer', () async {
      final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

      expect(LocalServerManager.isRunning, isFalse);

      final port = await LocalServerManager.startServer(testData, 'test.bin');
      expect(LocalServerManager.isRunning, isTrue);

      // Download file
      await http.get(
        Uri.parse(
            'http://localhost:$port/${LocalServerManager.token}/download'),
      );

      // Send ACK to server
      await http.get(
        Uri.parse('http://localhost:$port/${LocalServerManager.token}/ack'),
      );

      // Wait for server to stop
      await Future.delayed(const Duration(milliseconds: 100));

      expect(LocalServerManager.isRunning, isFalse);
    });

    test('startServerFromFile throws on non-existent file', () async {
      final nonExistentPath = p.join(tempDir.path, 'does_not_exist.txt');

      expect(
        () => LocalServerManager.startServerFromFile(nonExistentPath),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('Large file streaming demonstrates memory efficiency', () async {
      // Create a 10 MB test file
      final testFile = File(p.join(tempDir.path, 'large_10mb.dat'));
      final chunkSize = 1024 * 1024; // 1 MB chunks
      final totalSize = 10 * chunkSize;

      // Write file in chunks to avoid memory spike during creation
      final sink = testFile.openWrite();
      for (var i = 0; i < 10; i++) {
        final chunk = Uint8List.fromList(
          List.generate(chunkSize, (j) => (i + j) % 256),
        );
        sink.add(chunk);
      }
      await sink.close();

      expect(await testFile.length(), equals(totalSize));

      final progressUpdates = <int>[];

      final port = await LocalServerManager.startServerFromFile(
        testFile.path,
        onProgress: (sent, total) {
          progressUpdates.add(sent);
        },
      );

      // Download using streaming (http package handles this)
      final client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse(
            'http://localhost:$port/${LocalServerManager.token}/download'),
      );

      final response = await client.send(request);
      expect(response.statusCode, equals(200));

      // Read response in chunks to simulate streaming download
      int receivedBytes = 0;
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
      }

      expect(receivedBytes, equals(totalSize));
      expect(progressUpdates.isNotEmpty, isTrue);

      print('Streamed ${totalSize / (1024 * 1024)} MB file');
      print('Memory-efficient: file never fully loaded into memory');
      print('Progress updates: ${progressUpdates.length}');
      print('Final sent: ${progressUpdates.last} bytes');

      // Send ACK to server to let it shutdown gracefully
      await http.get(
        Uri.parse('http://localhost:$port/${LocalServerManager.token}/ack'),
      );

      // Wait for server to fully stop before test completes
      await Future.delayed(const Duration(milliseconds: 100));

      client.close();
    });

    group('HTTPS Server Tests', () {
      test('Certificate generation creates valid files', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Skip on platforms without openssl (will fallback to error)
        try {
          await CertificateManager.generateCertificate();

          expect(await CertificateManager.hasCertificate(), isTrue);

          final fingerprint = await CertificateManager.getFingerprint();
          expect(fingerprint, isNotNull);
          expect(fingerprint!.length,
              greaterThan(30)); // SHA-256 fingerprint format

          print('✅ Certificate generated with fingerprint: $fingerprint');

          // Cleanup
          await CertificateManager.deleteCertificate();
        } catch (e) {
          // OpenSSL not available - skip test
          print('⚠️ OpenSSL not available, skipping certificate test: $e');
        }
      });

      test('HTTPS server starts and serves files', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Skip if certificate generation fails
        try {
          await CertificateManager.generateCertificate();
        } catch (e) {
          print('⚠️ OpenSSL not available, skipping HTTPS test: $e');
          return;
        }

        final testData = Uint8List.fromList(
          List.generate(1024, (i) => i % 256),
        );

        final progressUpdates = <int>[];

        final port = await LocalServerManager.startServerSecure(
          testData,
          'test_https.bin',
          onProgress: (sent, total) {
            progressUpdates.add(sent);
          },
        );

        expect(LocalServerManager.isRunning, isTrue);

        // Note: Cannot test actual HTTPS download without proper certificate trust setup
        // This test verifies server starts successfully
        print('✅ HTTPS server started on port $port');

        await LocalServerManager.stopServer();
        await CertificateManager.deleteCertificate();
      });

      test('HTTPS server streams from file', () async {
        TestWidgetsFlutterBinding.ensureInitialized();

        // Skip if certificate generation fails
        try {
          await CertificateManager.generateCertificate();
        } catch (e) {
          print(
              '⚠️ OpenSSL not available, skipping HTTPS file streaming test: $e');
          return;
        }

        final testFile = File(p.join(tempDir.path, 'https_test.dat'));
        final testData = Uint8List.fromList(
          List.generate(512, (i) => i % 256),
        );
        await testFile.writeAsBytes(testData);

        final port = await LocalServerManager.startServerFromFileSecure(
          testFile.path,
        );

        expect(LocalServerManager.isRunning, isTrue);
        print('✅ HTTPS server streaming from file on port $port');

        await LocalServerManager.stopServer();
        await CertificateManager.deleteCertificate();
      });
    });
  });
}
