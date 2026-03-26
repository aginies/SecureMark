import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the cryptographic identity of the device for digital signing.
/// Uses Ed25519 algorithm for fast and compact signatures.
class IdentityManager {
  static final Ed25519 _algorithm = Ed25519();
  static const String _privateKeyPref = 'device_private_key';
  static const String _publicKeyPref = 'device_public_key';

  static SimpleKeyPair? _cachedKeyPair;
  static void Function(String)? onLog;

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
  /// Keys are stored in SharedPreferences.
  static Future<SimpleKeyPair> getIdentityKeyPair() async {
    try {
      if (_cachedKeyPair != null) {
        _log('Using cached key pair');
        return _cachedKeyPair!;
      }

      _log('Loading keys from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final String? privateKeyB64 = prefs.getString(_privateKeyPref);

      if (privateKeyB64 != null) {
        final String? publicKeyB64 = prefs.getString(_publicKeyPref);
        if (publicKeyB64 != null) {
          _log('Found existing keys in prefs (PK length: ${publicKeyB64.length})');
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

      _log('Keys generated, saving to SharedPreferences...');
      final successPriv = await prefs.setString(_privateKeyPref, base64Encode(privateKey));
      final successPub = await prefs.setString(_publicKeyPref, base64Encode(publicKey.bytes));

      _log('Save results: private=$successPriv, public=$successPub');

      _cachedKeyPair = keyPairData;
      return _cachedKeyPair!;    } catch (e, stack) {
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
  static Future<bool> verifySignature(
      List<int> data, String signatureB64, String publicKeyB64) async {
    try {
      final signatureBytes = base64Decode(signatureB64);
      final publicKeyBytes = base64Decode(publicKeyB64);

      final signature = Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      );

      return await _algorithm.verify(data, signature: signature);
    } catch (_) {
      return false;
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
  static Future<void> resetIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_privateKeyPref);
    await prefs.remove(_publicKeyPref);
    _cachedKeyPair = null;
  }
}
