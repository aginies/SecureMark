import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Legacy plaintext SharedPreferences keys (pre-secure-storage installs).
  /// The private key pref is only read for one-time migration and removed
  /// immediately afterwards.
  static const String _privateKeyPref = 'device_private_key';
  static const String _publicKeyPref = 'device_public_key';

  /// Platform secure storage key for the Ed25519 private key.
  static const String _securePrivateKeyKey = 'identity_ed25519_private_key';

  /// The private key lives in platform secure storage (Keychain on
  /// iOS/macOS, Keystore-backed AES-GCM on Android, libsecret on Linux,
  /// Credential Manager on Windows) so it is not readable in plaintext on a
  /// rooted or jailbroken device.
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

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
  ///
  /// The private key is stored in platform secure storage; the public key
  /// (not secret) remains in SharedPreferences.
  static Future<SimpleKeyPair> getIdentityKeyPair() async {
    try {
      if (_cachedKeyPair != null) {
        _log('Using cached key pair');
        return _cachedKeyPair!;
      }

      _log('Loading keys...');
      final prefs = await SharedPreferences.getInstance();
      final String? publicKeyB64 = prefs.getString(_publicKeyPref);
      String? privateKeyB64 = await _readSecurePrivateKey();

      if (privateKeyB64 == null && publicKeyB64 != null) {
        // One-time migration from the legacy plaintext pref.
        final legacyPrivate = prefs.getString(_privateKeyPref);
        if (legacyPrivate != null) {
          await _storePrivateKey(legacyPrivate);
          await prefs.remove(_privateKeyPref);
          _log('Migrated private key from prefs to platform secure storage');
          privateKeyB64 = legacyPrivate;
        }
      }

      if (privateKeyB64 != null && publicKeyB64 != null) {
        _log('Found existing keys (PK length: ${publicKeyB64.length})');
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

      _log('No keys found, generating new Ed25519 key pair...');
      final keyPair = await _algorithm.newKeyPair();
      final keyPairData = await keyPair.extract();

      // A leftover legacy private key without a matching public key is
      // corrupt state; drop it so no orphaned secret stays in plaintext.
      await prefs.remove(_privateKeyPref);
      await prefs.setString(
          _publicKeyPref, base64Encode(keyPairData.publicKey.bytes));
      await _storePrivateKey(base64Encode(keyPairData.bytes));

      _cachedKeyPair = keyPairData;
      return _cachedKeyPair!;
    } catch (e, stack) {
      _log('ERROR in getIdentityKeyPair: $e');
      _log('Stack: $stack');
      rethrow;
    }
  }

  /// Reads the private key from secure storage, returning null when the
  /// platform backend is unavailable instead of throwing.
  static Future<String?> _readSecurePrivateKey() async {
    try {
      return await _secureStorage.read(key: _securePrivateKeyKey);
    } catch (e) {
      _log('Secure storage read failed: $e');
      return null;
    }
  }

  /// Stores the private key in secure storage, falling back to the legacy
  /// plaintext pref when the platform backend is unavailable (e.g. a headless
  /// Linux without a keyring) so identity creation never hard-fails.
  static Future<void> _storePrivateKey(String privateKeyB64) async {
    try {
      await _secureStorage.write(
          key: _securePrivateKeyKey, value: privateKeyB64);
    } catch (e) {
      _log('Secure storage write failed, falling back to prefs: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_privateKeyPref, privateKeyB64);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privateKeyPref);
    await prefs.remove(_publicKeyPref);
    try {
      await _secureStorage.delete(key: _securePrivateKeyKey);
    } catch (_) {
      // Secure storage unavailable; nothing to delete there.
    }
    _cachedKeyPair = null;
    _log('Identity reset; notifying observers to drop cached results');
    onIdentityChanged?.call();
  }
}
