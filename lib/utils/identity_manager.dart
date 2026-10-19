import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Outcome of a signature verification attempt.
///
/// Distinguishing these states matters in a security feature: [invalid] means
/// the signature was well-formed but failed to verify against the data and
/// key (tampering, or a different key), while [error] means the inputs were
/// corrupt or unreadable, so no cryptographic conclusion could be drawn at
/// all. Treating both as plain "false" would present corrupt data as proof of
/// tampering.
enum SignatureVerification { valid, invalid, error }

/// Manages the cryptographic identity of the device for digital signing.
/// Uses Ed25519 algorithm for fast and compact signatures.
class IdentityManager {
  static final Ed25519 _algorithm = Ed25519();
  static const String _privateKeyPref = 'device_private_key';
  static const String _publicKeyPref = 'device_public_key';

  // The signing key pair lives in the platform secure storage (Android
  // Keystore / iOS Keychain) rather than plaintext SharedPreferences.
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static SimpleKeyPair? _cachedKeyPair;
  static void Function(String)? onLog;

  /// Invoked whenever the active signing identity changes (reset or explicit
  /// key injection). Callers use this to invalidate anything derived from the
  /// previous identity, such as the processor's result cache.
  static void Function()? onIdentityChanged;

  static void _log(String msg) {
    onLog?.call('[IdentityManager] $msg');
  }

  /// Initializes the manager with specific keys (useful for Isolates).
  static void initFromKeys(Uint8List privateKey, Uint8List publicKey) {
    _cachedKeyPair = SimpleKeyPairData(
      privateKey,
      publicKey: SimplePublicKey(
        publicKey,
        type: KeyPairType.ed25519,
      ),
      type: KeyPairType.ed25519,
    );
    _log('Initialized from provided keys');
    onIdentityChanged?.call();
  }

  /// Gets the raw private key bytes.
  static Future<Uint8List> getDevicePrivateKey() async {
    final keyPair = await getIdentityKeyPair();
    final data = await keyPair.extract();
    return Uint8List.fromList(data.bytes);
  }

  /// Gets the raw public key bytes.
  static Future<Uint8List> getDevicePublicKeyBytes() async {
    final keyPair = await getIdentityKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  /// Gets or creates the device identity key pair.
  /// Keys are stored in the platform secure storage (encrypted at rest).
  static Future<SimpleKeyPair> getIdentityKeyPair() async {
    try {
      if (_cachedKeyPair != null) {
        _log('Using cached key pair');
        return _cachedKeyPair!;
      }

      _log('Loading keys from secure storage...');
      final String? privateKeyB64 = await _storage.read(key: _privateKeyPref);

      if (privateKeyB64 != null) {
        final String? publicKeyB64 = await _storage.read(key: _publicKeyPref);
        if (publicKeyB64 != null) {
          _log('Found existing keys in secure storage '
              '(PK length: ${publicKeyB64.length})');
          // Load existing key
          final privateKeyBytes = base64Decode(privateKeyB64);
          final publicKeyBytes = base64Decode(publicKeyB64);

          _cachedKeyPair = SimpleKeyPairData(
            privateKeyBytes,
            publicKey: SimplePublicKey(
              publicKeyBytes,
              type: KeyPairType.ed25519,
            ),
            type: KeyPairType.ed25519,
          );
          return _cachedKeyPair!;
        }
      }

      _log('No keys found, generating new Ed25519 key pair...');
      // Generate new key if none exists or corrupted
      final keyPair = await _algorithm.newKeyPair();
      final keyPairData = await keyPair.extract();
      final privateKey = keyPairData.bytes;
      final publicKey = keyPairData.publicKey;

      _log('Keys generated, saving to secure storage...');
      await _storage.write(
          key: _privateKeyPref, value: base64Encode(privateKey));
      await _storage.write(
          key: _publicKeyPref, value: base64Encode(publicKey.bytes));

      _cachedKeyPair = keyPairData;
      return _cachedKeyPair!;
    } catch (e, stack) {
      _log('ERROR in getIdentityKeyPair: $e');
      _log('Stack: $stack');
      rethrow;
    }
  }

  /// Signs data with the device identity key and returns Base64 signature.
  static Future<String> signData(List<int> data) async {
    final keyPair = await getIdentityKeyPair();
    final signature = await _algorithm.sign(data, keyPair: keyPair);
    return base64Encode(signature.bytes);
  }

  /// Verifies a signature using a public key.
  ///
  /// Returns [SignatureVerification.error] when the signature or key bytes
  /// are corrupt (undecodable, wrong size) and [SignatureVerification.invalid]
  /// when they are well-formed but do not verify. Callers must not conflate
  /// the two: a corrupt signature is not evidence of tampering, but it is
  /// not evidence of integrity either.
  static Future<SignatureVerification> verifySignature(
      List<int> data, String signatureB64, String publicKeyB64) async {
    try {
      final signatureBytes = base64Decode(signatureB64);
      final publicKeyBytes = base64Decode(publicKeyB64);

      final signature = Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      );

      return await _algorithm.verify(data, signature: signature)
          ? SignatureVerification.valid
          : SignatureVerification.invalid;
    } catch (_) {
      return SignatureVerification.error;
    }
  }

  /// Gets the device public key as a Base64 string.
  static Future<String> getDevicePublicKey() async {
    final keyPair = await getIdentityKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final result = base64Encode(publicKey.bytes);
    _log('getDevicePublicKey returning string of length ${result.length}');
    return result;
  }

  /// Gets a short fingerprint of the public key for display.
  static Future<String> getDeviceFingerprint() async {
    final pk = await getDevicePublicKey();
    if (pk.length < 12) return pk;
    return '${pk.substring(0, 6)}...${pk.substring(pk.length - 6)}';
  }

  /// Resets the identity (use with caution).
  ///
  /// Any cached output signed by the outgoing key is stale, so observers are
  /// notified via [onIdentityChanged] once the new state is in effect.
  static Future<void> resetIdentity() async {
    await _storage.delete(key: _privateKeyPref);
    await _storage.delete(key: _publicKeyPref);
    _cachedKeyPair = null;
    _log('Identity reset; notifying observers to drop cached results');
    onIdentityChanged?.call();
  }
}
