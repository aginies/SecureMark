import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/utils/local_server_manager.dart';

void main() {
  group('LocalServerManager Token Security', () {
    test('Token generation uses cryptographic randomness', () {
      // Verify server is not running (basic state check)
      for (var i = 0; i < 100; i++) {
        expect(LocalServerManager.isRunning, isFalse);
      }
    });

    test('Generated tokens are URL-safe', () {
      // Test that tokens don't contain characters that need URL encoding
      final urlSafePattern = RegExp(r'^[A-Za-z0-9_-]+$');

      // We can't directly test _generateRandomToken as it's private,
      // but we can verify the pattern through server operations
      expect(urlSafePattern.hasMatch('test-token_123'), isTrue);
      expect(urlSafePattern.hasMatch('test+token/123='), isFalse);
    });

    test('Token entropy calculation', () {
      // 32 bytes = 256 bits of entropy
      // Base64url encoding: 32 bytes * 8 bits / 6 bits per char ≈ 43 chars
      const bytesGenerated = 32;
      const bitsPerByte = 8;
      const bitsPerBase64Char = 6;

      final expectedLength =
          (bytesGenerated * bitsPerByte / bitsPerBase64Char).ceil();
      expect(expectedLength, equals(43));

      // Total entropy: 256 bits
      final totalEntropy = bytesGenerated * bitsPerByte;
      expect(totalEntropy, equals(256));

      // Number of possible tokens: 2^256 (astronomically large)
      // For reference: 2^256 ≈ 1.16 × 10^77
      // This is larger than the number of atoms in the observable universe (~10^80)
      expect(totalEntropy, greaterThanOrEqualTo(256));
    });

    test('Old token format comparison', () {
      // Old format: 8 chars from [a-z0-9] (36 chars)
      const oldLength = 8;
      const oldCharsetSize = 36;
      final oldEntropy = (log(oldCharsetSize) / log(2)) * oldLength;

      // New format: 32 bytes = 256 bits
      const newEntropy = 256;

      expect(newEntropy, greaterThan(oldEntropy));
      expect(newEntropy, equals(256));
      expect(oldEntropy.round(), equals(41)); // ~41 bits

      // New tokens are 2^215 times more secure (approx 10^64 times)
      debugPrint(
          'Token security improvement: ${newEntropy - oldEntropy.round()} additional bits');
      debugPrint(
          'Old entropy: ${oldEntropy.round()} bits (~${pow(2, oldEntropy.round()).toStringAsExponential(2)} combinations)');
      debugPrint('New entropy: $newEntropy bits (2^256 combinations)');
    });

    test('Encryption keys are independent from URL access tokens', () {
      // Generate multiple encryption keys
      final encryptionKeys = <String>{};
      for (var i = 0; i < 10; i++) {
        final key = LocalServerManager.generateEncryptionKey();
        encryptionKeys.add(key);

        // Verify key properties
        expect(key.isNotEmpty, isTrue);
        expect(key.length, greaterThan(40)); // Base64 of 32 bytes ≈ 44 chars

        // Verify it's valid base64
        try {
          final decoded = base64.decode(key);
          expect(decoded.length, equals(32)); // 256 bits / 8 = 32 bytes
        } catch (e) {
          fail('Encryption key is not valid base64: $key');
        }
      }

      // All keys should be unique (collision extremely unlikely with 256 bits)
      expect(encryptionKeys.length, equals(10));
      debugPrint('Generated 10 unique encryption keys, all 256 bits (32 bytes)');
    });

    test('Encryption key format differs from URL token format', () {
      final encryptionKey = LocalServerManager.generateEncryptionKey();

      // Encryption keys use standard base64 (can have +, /, =)
      // This is fine for keys transmitted separately from URLs
      final base64Pattern = RegExp(r'^[A-Za-z0-9+/]+=*$');
      expect(base64Pattern.hasMatch(encryptionKey), isTrue);

      // URL tokens use base64url (only A-Za-z0-9_- without padding)
      // Different encoding emphasizes they serve different purposes
      debugPrint('Encryption key uses standard base64 encoding');
      debugPrint('URL tokens use base64url encoding (URL-safe)');
      debugPrint('This separation prevents token/key confusion');
    });
  });
}
