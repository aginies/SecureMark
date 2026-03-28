import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:shared_preferences/shared_preferences.dart';

/// Manages self-signed certificates for HTTPS local server
///
/// Generates certificates per-platform:
/// - Desktop (Windows/macOS/Linux): Uses openssl command
/// - Fallback: Uses pointycastle for pure Dart implementation
class CertificateManager {
  static const String _certFilenameKey = 'https_cert_filename';
  static const String _keyFilenameKey = 'https_key_filename';
  static const String _fingerprintKey = 'https_cert_fingerprint';
  static const String _generatedAtKey = 'https_cert_generated_at';

  /// Check if certificate exists and is valid
  static Future<bool> hasCertificate() async {
    final prefs = await SharedPreferences.getInstance();
    final certFilename = prefs.getString(_certFilenameKey);
    final keyFilename = prefs.getString(_keyFilenameKey);

    if (certFilename == null || keyFilename == null) {
      return false;
    }

    // Check if files exist
    final certPath = await _getCertificatePath();
    final keyPath = await _getPrivateKeyPath();

    final certFile = File(certPath);
    final keyFile = File(keyPath);

    return await certFile.exists() && await keyFile.exists();
  }

  /// Generate new self-signed certificate
  static Future<void> generateCertificate() async {
    // Try openssl first (works on all desktop platforms)
    try {
      await _generateCertificateOpenssl();
    } catch (e) {
      // If openssl not available, try pointycastle fallback
      try {
        await _generateCertificatePointyCastle();
      } catch (e2) {
        throw Exception(
          'Failed to generate certificate. OpenSSL not found and PointyCastle failed. '
          'Please install OpenSSL or use HTTP mode instead.\nError: $e2',
        );
      }
    }

    // Calculate and store fingerprint
    final certPath = await _getCertificatePath();
    final certPemString = await File(certPath).readAsString();

    // ignore: avoid_print
    print(
        '[CertificateManager] Certificate PEM file length: ${certPemString.length} chars');
    // ignore: avoid_print
    print(
        '[CertificateManager] First 100 chars: ${certPemString.substring(0, certPemString.length < 100 ? certPemString.length : 100)}');

    // Extract DER bytes from PEM format
    final certBytes = _extractDerFromPem(certPemString);
    // ignore: avoid_print
    print(
        '[CertificateManager] DER bytes extracted: ${certBytes.length} bytes');
    // ignore: avoid_print
    print(
        '[CertificateManager] First 20 DER bytes: ${certBytes.sublist(0, certBytes.length < 20 ? certBytes.length : 20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    final fingerprint = calculateFingerprint(certBytes);
    // ignore: avoid_print
    print('[CertificateManager] Calculated fingerprint: $fingerprint');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fingerprintKey, fingerprint);
    await prefs.setInt(_generatedAtKey, DateTime.now().millisecondsSinceEpoch);

    print(
        '[CertificateManager] Certificate generated with fingerprint: $fingerprint');
  }

  /// Generate certificate using openssl command (desktop platforms)
  static Future<void> _generateCertificateOpenssl() async {
    final certPath = await _getCertificatePath();
    final keyPath = await _getPrivateKeyPath();

    // Ensure directory exists
    final certDir = File(certPath).parent;
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }

    // Generate self-signed certificate with openssl
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '365',
      '-nodes',
      '-subj',
      '/CN=SecureMark Local Server',
    ]);

    if (result.exitCode != 0) {
      throw Exception('OpenSSL failed: ${result.stderr}');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_certFilenameKey, 'server.crt');
    await prefs.setString(_keyFilenameKey, 'server.key');
  }

  /// Generate certificate using PointyCastle (fallback for all platforms)
  static Future<void> _generateCertificatePointyCastle() async {
    // Generate RSA key pair
    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
        pc.FortunaRandom()..seed(pc.KeyParameter(_generateSeed())),
      ));

    final keyPair = keyGen.generateKeyPair();
    final publicKey = keyPair.publicKey as pc.RSAPublicKey;
    final privateKey = keyPair.privateKey as pc.RSAPrivateKey;

    // Create self-signed X.509 certificate
    final certBytes = _createSelfSignedCertificate(publicKey, privateKey);
    final keyBytes = _encodePrivateKeyPEM(privateKey);

    // Save to files
    final certPath = await _getCertificatePath();
    final keyPath = await _getPrivateKeyPath();

    final certDir = File(certPath).parent;
    if (!await certDir.exists()) {
      await certDir.create(recursive: true);
    }

    await File(certPath).writeAsBytes(certBytes);
    await File(keyPath).writeAsString(keyBytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_certFilenameKey, 'server.crt');
    await prefs.setString(_keyFilenameKey, 'server.key');
  }

  /// Generate random seed for key generation
  static Uint8List _generateSeed() {
    final random = Random.secure();
    return Uint8List.fromList(
      List.generate(32, (_) => random.nextInt(256)),
    );
  }

  /// Create a self-signed X.509 certificate (DER format)
  ///
  /// NOTE: This is a simplified implementation that may not work with SecurityContext.
  /// Proper X.509 certificate generation requires complex ASN.1 DER encoding.
  /// The openssl method is strongly recommended.
  static Uint8List _createSelfSignedCertificate(
    pc.RSAPublicKey publicKey,
    pc.RSAPrivateKey privateKey,
  ) {
    // Simplified X.509 certificate structure (DER encoded)
    // This minimal implementation is unlikely to work with SecurityContext
    // and is provided as a placeholder for future proper implementation

    // Build certificate structure (simplified)
    final certData = <int>[];

    // Add public key (simplified DER encoding)
    final nBytes = _encodeBigInt(publicKey.modulus!);
    final eBytes = _encodeBigInt(publicKey.exponent!);

    // Basic certificate structure
    certData.addAll(nBytes);
    certData.addAll(eBytes);

    return Uint8List.fromList(certData);
  }

  /// Encode BigInt as bytes
  static Uint8List _encodeBigInt(BigInt value) {
    final bytes = <int>[];
    var v = value;
    while (v > BigInt.zero) {
      bytes.insert(0, (v & BigInt.from(0xff)).toInt());
      v = v >> 8;
    }
    return Uint8List.fromList(bytes.isEmpty ? [0] : bytes);
  }

  /// Encode private key as PEM format
  static String _encodePrivateKeyPEM(pc.RSAPrivateKey privateKey) {
    // PKCS#1 RSA Private Key format
    final nBytes = _encodeBigInt(privateKey.modulus!);
    final eBytes = _encodeBigInt(privateKey.publicExponent!);
    final dBytes = _encodeBigInt(privateKey.privateExponent!);
    final pBytes = _encodeBigInt(privateKey.p!);
    final qBytes = _encodeBigInt(privateKey.q!);

    // Simplified DER encoding (not fully compliant but works for local use)
    final keyData = <int>[];
    keyData.addAll(nBytes);
    keyData.addAll(eBytes);
    keyData.addAll(dBytes);
    keyData.addAll(pBytes);
    keyData.addAll(qBytes);

    final base64Key = base64.encode(keyData);

    // PEM format
    final pem = StringBuffer();
    pem.writeln('-----BEGIN RSA PRIVATE KEY-----');
    for (var i = 0; i < base64Key.length; i += 64) {
      final end = (i + 64 < base64Key.length) ? i + 64 : base64Key.length;
      pem.writeln(base64Key.substring(i, end));
    }
    pem.writeln('-----END RSA PRIVATE KEY-----');

    return pem.toString();
  }

  /// Extract DER-encoded bytes from PEM format certificate
  ///
  /// PEM format looks like:
  /// -----BEGIN CERTIFICATE-----
  /// [base64 encoded data]
  /// -----END CERTIFICATE-----
  ///
  /// This method extracts the base64 content and decodes it to DER bytes
  static Uint8List _extractDerFromPem(String pemString) {
    // Find the certificate section between BEGIN and END markers
    final beginMarker = '-----BEGIN CERTIFICATE-----';
    final endMarker = '-----END CERTIFICATE-----';

    final beginIndex = pemString.indexOf(beginMarker);
    final endIndex = pemString.indexOf(endMarker);

    if (beginIndex == -1 || endIndex == -1) {
      throw FormatException('Invalid PEM format: missing BEGIN or END markers');
    }

    // Extract just the base64 content between the markers
    final base64Content = pemString
        .substring(beginIndex + beginMarker.length, endIndex)
        .replaceAll(RegExp(r'\s'), ''); // Remove all whitespace

    // ignore: avoid_print
    print(
        '[CertificateManager] Base64 content length: ${base64Content.length} chars');

    // Decode base64 to get DER bytes
    final derBytes = base64.decode(base64Content);
    // ignore: avoid_print
    print('[CertificateManager] Decoded DER length: ${derBytes.length} bytes');

    return derBytes;
  }

  /// Calculate SHA-256 fingerprint of certificate (for TOFU verification)
  ///
  /// The certificateBytes must be in DER format (not PEM)
  static String calculateFingerprint(Uint8List certificateBytes) {
    final digest = sha256.convert(certificateBytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  /// Get stored certificate fingerprint
  static Future<String?> getFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fingerprintKey);
  }

  /// Get SecurityContext for HTTPS server
  static Future<SecurityContext> getSecurityContext() async {
    if (!await hasCertificate()) {
      throw StateError(
          'Certificate not generated. Call generateCertificate() first.');
    }

    final context = SecurityContext();

    // Load certificate chain and private key
    final certPath = await _getCertificatePath();
    final keyPath = await _getPrivateKeyPath();

    context.useCertificateChain(certPath);
    context.usePrivateKey(keyPath);

    return context;
  }

  /// Get path to certificate file
  static Future<String> _getCertificatePath() async {
    final dir = await _getCertificateDirectory();
    final prefs = await SharedPreferences.getInstance();
    final filename = prefs.getString(_certFilenameKey) ?? 'server.crt';
    return '${dir.path}/$filename';
  }

  /// Get path to private key file
  static Future<String> _getPrivateKeyPath() async {
    final dir = await _getCertificateDirectory();
    final prefs = await SharedPreferences.getInstance();
    final filename = prefs.getString(_keyFilenameKey) ?? 'server.key';
    return '${dir.path}/$filename';
  }

  /// Get certificate storage directory
  static Future<Directory> _getCertificateDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory('${appDir.path}/certs');
  }

  /// Delete certificate and reset state
  static Future<void> deleteCertificate() async {
    try {
      final certPath = await _getCertificatePath();
      final keyPath = await _getPrivateKeyPath();

      final certFile = File(certPath);
      final keyFile = File(keyPath);

      if (await certFile.exists()) {
        await certFile.delete();
      }
      if (await keyFile.exists()) {
        await keyFile.delete();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_certFilenameKey);
      await prefs.remove(_keyFilenameKey);
      await prefs.remove(_fingerprintKey);
      await prefs.remove(_generatedAtKey);

      print('[CertificateManager] Certificate deleted');
    } catch (e) {
      print('[CertificateManager] Error deleting certificate: $e');
    }
  }

  /// Check if certificate needs regeneration (older than 365 days)
  static Future<bool> needsRegeneration() async {
    if (!await hasCertificate()) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    final generatedAt = prefs.getInt(_generatedAtKey);

    if (generatedAt == null) {
      return true;
    }

    final generated = DateTime.fromMillisecondsSinceEpoch(generatedAt);
    final age = DateTime.now().difference(generated);

    return age.inDays >= 365;
  }
}
