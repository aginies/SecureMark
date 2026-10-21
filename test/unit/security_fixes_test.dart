import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/utils/secure_http_client.dart';
import 'package:secure_mark/utils/watermark_utils.dart';

void main() {
  group('Security Fixes: Network & HTTP Client', () {
    test('downloadWithFingerprint rejects plain HTTP URLs', () async {
      expect(
        () => SecureHttpClient.downloadWithFingerprint(
          url: 'http://example.com/file.bin',
          expectedFingerprint: 'AA:BB:CC',
          outputPath: '/tmp/test.bin',
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('HTTPS required'),
        )),
      );
    });

    test('downloadWithFingerprint rejects malformed or non-http URLs',
        () async {
      expect(
        () => SecureHttpClient.downloadWithFingerprint(
          url: 'ftp://example.com/file.bin',
          expectedFingerprint: 'AA:BB:CC',
          outputPath: '/tmp/test.bin',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Security Fixes: Web ZIP Encryption', () {
    test('ZipEncoder encrypts archive when password is provided', () {
      final archive = Archive();
      final content =
          Uint8List.fromList('Confidential document bytes'.codeUnits);
      archive.addFile(ArchiveFile('secret.txt', content.length, content));

      const password = 'CorrectHorseBatteryStaple123!';
      final encryptedBytes = Uint8List.fromList(
        ZipEncoder(password: password).encode(archive),
      );

      expect(encryptedBytes, isNotEmpty);

      // Decoding without password should fail or throw ArchiveException when accessing content
      final decodedArchive = ZipDecoder().decodeBytes(encryptedBytes);
      expect(decodedArchive.files.length, equals(1));
      final decodedFile = decodedArchive.files.first;

      // In archive package, encrypted files cannot be decrypted without password
      expect(
        () => decodedFile.content,
        throwsA(isA<ArchiveException>()),
      );

      // Decoding with password should recover plaintext
      final decryptedArchive =
          ZipDecoder().decodeBytes(encryptedBytes, password: password);
      expect(
          decryptedArchive.files.first.content as List<int>, equals(content));
    });

    test('ZipEncoder produces unencrypted archive when password is null', () {
      final archive = Archive();
      final content = Uint8List.fromList('Public document bytes'.codeUnits);
      archive.addFile(ArchiveFile('public.txt', content.length, content));

      final plainBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final decodedArchive = ZipDecoder().decodeBytes(plainBytes);
      expect(decodedArchive.files.first.content as List<int>, equals(content));
    });
  });

  group('Security Fixes: Path and Filename Sanitization', () {
    test('WatermarkUtils.sanitizeFileName neutralizes path traversals', () {
      expect(WatermarkUtils.sanitizeFileName('../../../etc/passwd'),
          equals('passwd'));
      expect(
        WatermarkUtils.sanitizeFileName('..\\..\\windows\\system32\\cmd.exe'),
        equals('cmd.exe'),
      );
      expect(
        WatermarkUtils.sanitizeFileName('normal_file.pdf'),
        equals('normal_file.pdf'),
      );
    });

    test(
        'WatermarkUtils.mimeTypeForPath handles uppercase and uncommon formats',
        () {
      expect(
          WatermarkUtils.mimeTypeForPath('DOC.PDF'), equals('application/pdf'));
      expect(
          WatermarkUtils.mimeTypeForPath('image.JPEG'), equals('image/jpeg'));
      expect(
          WatermarkUtils.mimeTypeForPath('image.WebP'), equals('image/webp'));
      expect(WatermarkUtils.mimeTypeForPath('other.bin'),
          equals('application/octet-stream'));
    });
  });
}
