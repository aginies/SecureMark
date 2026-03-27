import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';

class EncryptionUtils {
  static int crc16(List<int> data) {
    var crc = 0xFFFF;
    for (var b in data) {
      crc ^= b;
      for (var i = 0; i < 8; i++) {
        if ((crc & 0x0001) != 0) {
          crc = (crc >> 1) ^ 0xA001;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc;
  }

  /// Encrypts data with AES-256-CBC and HMAC-SHA256 for authenticated encryption
  /// Format: salt(32) + iv(16) + hmac(32) + ciphertext
  /// Uses PBKDF2 with 100k iterations for key derivation
  static Uint8List encryptBytes(Uint8List data, String password) {
    // Generate random salt for PBKDF2
    final random = Random.secure();
    final salt = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );

    // Derive encryption and HMAC keys using PBKDF2
    final keys = _deriveKeysSync(password, salt);
    final encryptionKey = keys.encryptionKey;
    final hmacKey = keys.hmacKey;

    // Generate random IV
    final iv = enc.IV.fromSecureRandom(16);

    // Encrypt data
    final key = enc.Key(encryptionKey);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    // Calculate HMAC over salt + iv + ciphertext
    final dataToAuth = BytesBuilder()
      ..add(salt)
      ..add(iv.bytes)
      ..add(encrypted.bytes);
    final hmacBytes = Hmac(sha256, hmacKey).convert(dataToAuth.toBytes()).bytes;

    // Assemble final format: salt + iv + hmac + ciphertext
    final result = BytesBuilder()
      ..add(salt)
      ..add(iv.bytes)
      ..add(hmacBytes)
      ..add(encrypted.bytes);

    return result.toBytes();
  }

  /// Decrypts data encrypted with encryptBytes, verifying HMAC first
  /// Format: salt(32) + iv(16) + hmac(32) + ciphertext
  static Uint8List? decryptBytes(Uint8List encryptedData, String password) {
    try {
      // Minimum size: 32 (salt) + 16 (iv) + 32 (hmac) + 16 (one AES block)
      if (encryptedData.length < 96) {
        debugPrint('Decryption error: Data too short');
        return null;
      }

      // Parse components
      final salt = encryptedData.sublist(0, 32);
      final iv = enc.IV(encryptedData.sublist(32, 48));
      final storedHmac = encryptedData.sublist(48, 80);
      final ciphertext = encryptedData.sublist(80);

      // Ensure ciphertext is a multiple of 16 (AES block size)
      if (ciphertext.length % 16 != 0) {
        debugPrint('Decryption error: Invalid ciphertext length');
        return null;
      }

      // Derive keys using same salt
      final keys = _deriveKeysSync(password, salt);
      final encryptionKey = keys.encryptionKey;
      final hmacKey = keys.hmacKey;

      // Verify HMAC before decryption (authenticate-then-decrypt)
      final dataToAuth = BytesBuilder()
        ..add(salt)
        ..add(iv.bytes)
        ..add(ciphertext);
      final computedHmac =
          Hmac(sha256, hmacKey).convert(dataToAuth.toBytes()).bytes;

      // Constant-time comparison to prevent timing attacks
      if (!_constantTimeCompare(storedHmac, computedHmac)) {
        debugPrint(
            'Decryption error: HMAC verification failed (wrong password or tampered data)');
        return null;
      }

      // HMAC verified, now decrypt
      final key = enc.Key(encryptionKey);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted =
          encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: iv);

      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

  /// Synchronous PBKDF2 implementation using HMAC-SHA256
  /// Derives 64 bytes: 32 for encryption key + 32 for HMAC key
  static _DerivedKeys _deriveKeysSync(String password, Uint8List salt) {
    const iterations = 100000; // OWASP recommendation
    const dkLen = 64; // 512 bits total
    const hLen = 32; // SHA-256 output length

    final passwordBytes = utf8.encode(password);
    final numBlocks = (dkLen / hLen).ceil();
    final derivedKey = BytesBuilder();

    // PBKDF2 algorithm (RFC 2898)
    for (var blockNum = 1; blockNum <= numBlocks; blockNum++) {
      // U_1 = PRF(password, salt || INT_32_BE(blockNum))
      final blockData = BytesBuilder()
        ..add(salt)
        ..add(_int32BigEndian(blockNum));

      var u = Hmac(sha256, passwordBytes).convert(blockData.toBytes()).bytes;
      var result = List<int>.from(u);

      // U_i = PRF(password, U_(i-1))
      for (var i = 1; i < iterations; i++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var j = 0; j < hLen; j++) {
          result[j] ^= u[j]; // XOR all iterations
        }
      }

      derivedKey.add(result);
    }

    final keyBytes = derivedKey.toBytes().sublist(0, dkLen);

    // Split into encryption key (first 32 bytes) and HMAC key (last 32 bytes)
    return _DerivedKeys(
      encryptionKey: Uint8List.fromList(keyBytes.sublist(0, 32)),
      hmacKey: Uint8List.fromList(keyBytes.sublist(32, 64)),
    );
  }

  /// Convert integer to 32-bit big-endian bytes
  static Uint8List _int32BigEndian(int value) {
    return Uint8List(4)
      ..[0] = (value >> 24) & 0xFF
      ..[1] = (value >> 16) & 0xFF
      ..[2] = (value >> 8) & 0xFF
      ..[3] = value & 0xFF;
  }

  /// Constant-time comparison to prevent timing attacks
  static bool _constantTimeCompare(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }
}

/// Container for derived encryption and HMAC keys
class _DerivedKeys {
  final Uint8List encryptionKey;
  final Uint8List hmacKey;

  _DerivedKeys({required this.encryptionKey, required this.hmacKey});
}
