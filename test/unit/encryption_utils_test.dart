import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/steganography/encryption_utils.dart';

void main() {
  group('Authenticated Encryption Tests', () {
    test('Encrypt and decrypt round-trip with correct password', () {
      final testData =
          utf8.encode('SecureMark test data with sensitive content');
      final password = 'test-password-123';

      final encrypted = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        password,
      );

      // Verify encrypted format
      expect(encrypted.length, greaterThanOrEqualTo(96)); // Min: 32+16+32+16
      expect(encrypted.length, greaterThan(testData.length)); // Has overhead

      final decrypted = EncryptionUtils.decryptBytes(encrypted, password);

      expect(decrypted, isNotNull);
      expect(decrypted, equals(testData));
    });

    test('Decryption fails with wrong password', () {
      final testData = utf8.encode('Sensitive document content');
      final correctPassword = 'correct-password';
      final wrongPassword = 'wrong-password';

      final encrypted = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        correctPassword,
      );

      final decrypted = EncryptionUtils.decryptBytes(encrypted, wrongPassword);

      // HMAC verification should fail with wrong password
      expect(decrypted, isNull);
    });

    test('Decryption detects tampering (modified ciphertext)', () {
      final testData = utf8.encode('Important data');
      final password = 'secure-password';

      final encrypted = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        password,
      );

      // Tamper with ciphertext (flip a bit in the encrypted data)
      final tampered = Uint8List.fromList(encrypted);
      tampered[encrypted.length - 1] ^= 0x01; // Flip last bit

      final decrypted = EncryptionUtils.decryptBytes(tampered, password);

      // HMAC verification should detect tampering
      expect(decrypted, isNull);
    });

    test('Decryption detects tampering (modified HMAC)', () {
      final testData = utf8.encode('Confidential information');
      final password = 'my-password';

      final encrypted = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        password,
      );

      // Tamper with HMAC (modify byte in HMAC section: positions 48-79)
      final tampered = Uint8List.fromList(encrypted);
      tampered[50] ^= 0xFF; // Flip bits in HMAC

      final decrypted = EncryptionUtils.decryptBytes(tampered, password);

      // HMAC verification should fail
      expect(decrypted, isNull);
    });

    test('Each encryption produces different ciphertext (random salt/IV)', () {
      final testData = utf8.encode('Same data, different encryption');
      final password = 'same-password';

      final encrypted1 = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        password,
      );
      final encrypted2 = EncryptionUtils.encryptBytes(
        Uint8List.fromList(testData),
        password,
      );

      // Different salt and IV should produce different ciphertext
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both should decrypt to same plaintext
      final decrypted1 = EncryptionUtils.decryptBytes(encrypted1, password);
      final decrypted2 = EncryptionUtils.decryptBytes(encrypted2, password);

      expect(decrypted1, equals(testData));
      expect(decrypted2, equals(testData));
    });

    test('Encryption format verification', () {
      final testData = Uint8List(100); // 100 bytes of zeros
      final password = 'format-test';

      final encrypted = EncryptionUtils.encryptBytes(testData, password);

      // Format: salt(32) + iv(16) + hmac(32) + ciphertext
      // Ciphertext should be padded to multiple of 16 (AES block size)
      final expectedMinSize = 32 + 16 + 32 + 112; // 112 = 100 rounded up to 16
      expect(encrypted.length, equals(expectedMinSize));

      // Extract components
      final salt = encrypted.sublist(0, 32);
      final iv = encrypted.sublist(32, 48);
      final hmac = encrypted.sublist(48, 80);
      final ciphertext = encrypted.sublist(80);

      // Verify component sizes
      expect(salt.length, equals(32));
      expect(iv.length, equals(16));
      expect(hmac.length, equals(32));
      expect(ciphertext.length % 16, equals(0)); // Multiple of AES block size
    });

    test('Handles large data efficiently', () {
      final testData = Uint8List(1024 * 1024); // 1 MB of data
      final password = 'large-data-password';

      final stopwatch = Stopwatch()..start();
      final encrypted = EncryptionUtils.encryptBytes(testData, password);
      final encryptTime = stopwatch.elapsedMilliseconds;
      stopwatch.reset();

      final decrypted = EncryptionUtils.decryptBytes(encrypted, password);
      final decryptTime = stopwatch.elapsedMilliseconds;
      stopwatch.stop();

      expect(decrypted, isNotNull);
      expect(decrypted!.length, equals(testData.length));

      print('Encrypted 1MB in ${encryptTime}ms, decrypted in ${decryptTime}ms');
      print('PBKDF2 (100k iterations) overhead included in timing');
    });

    test('Decryption rejects data that is too short', () {
      final tooShort = Uint8List(50); // Less than minimum 96 bytes
      final password = 'test';

      final decrypted = EncryptionUtils.decryptBytes(tooShort, password);

      expect(decrypted, isNull);
    });

    test('PBKDF2 key derivation produces consistent keys', () {
      final password = 'pbkdf2-test';
      final data = utf8.encode('test');

      // Encrypt twice with same password
      final encrypted1 = EncryptionUtils.encryptBytes(
        Uint8List.fromList(data),
        password,
      );
      final encrypted2 = EncryptionUtils.encryptBytes(
        Uint8List.fromList(data),
        password,
      );

      // Different salts mean different derived keys, so different outputs
      expect(encrypted1, isNot(equals(encrypted2)));

      // But both should decrypt successfully with same password
      expect(EncryptionUtils.decryptBytes(encrypted1, password), equals(data));
      expect(EncryptionUtils.decryptBytes(encrypted2, password), equals(data));
    });
  });
}
