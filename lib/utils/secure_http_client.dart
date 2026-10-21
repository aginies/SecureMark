import 'dart:io';

import 'package:crypto/crypto.dart';

/// Secure HTTP client with certificate fingerprint verification (TOFU model)
///
/// Downloads files over HTTPS with self-signed certificate verification
/// using Trust On First Use (TOFU) model. Users verify the certificate
/// fingerprint from the QR code before downloading.
class SecureHttpClient {
  /// Download file with certificate fingerprint verification
  ///
  /// [url] - HTTPS URL to download from
  /// [expectedFingerprint] - SHA-256 fingerprint of the server's certificate (from QR code)
  /// [outputPath] - Where to save the downloaded file
  /// [onProgress] - Optional progress callback (bytesReceived, totalBytes)
  ///
  /// Throws [CertificateException] if fingerprint doesn't match
  /// Throws [HttpException] for HTTP errors
  static Future<void> downloadWithFingerprint({
    required String url,
    required String expectedFingerprint,
    required String outputPath,
    Function(int, int)? onProgress,
  }) async {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty || parsed.scheme != 'https') {
      throw ArgumentError(
          'HTTPS required for certificate fingerprint verification: $url');
    }

    final client = HttpClient();

    try {
      bool? cachedVerificationResult;

      // Configure client to verify certificate fingerprint
      client.badCertificateCallback = (cert, host, port) {
        if (cachedVerificationResult != null) {
          return cachedVerificationResult!;
        }

        // Calculate actual fingerprint from certificate
        final actualFingerprint = _calculateCertFingerprint(cert);

        // TOFU verification: Accept only if fingerprint matches
        cachedVerificationResult = actualFingerprint == expectedFingerprint;

        return cachedVerificationResult!;
      };

      // Download file
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}: Failed to download file',
        );
      }

      // Get content length for progress tracking
      final contentLength = response.contentLength;

      // Stream to file (memory-efficient)
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      int receivedBytes = 0;
      final stopwatch = Stopwatch()..start();
      const progressUpdateInterval = Duration(milliseconds: 100);

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        // Report progress with throttling (every 100ms or on completion)
        if (onProgress != null && contentLength > 0) {
          if (receivedBytes == contentLength ||
              stopwatch.elapsed >= progressUpdateInterval) {
            onProgress(receivedBytes, contentLength);
            stopwatch.reset();
          }
        }
      }

      await sink.flush();
      await sink.close();
    } catch (e) {
      // Clean up partial file on error
      final file = File(outputPath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Calculate SHA-256 fingerprint from X509Certificate
  static String _calculateCertFingerprint(X509Certificate cert) {
    // Get DER-encoded certificate bytes
    final der = cert.der;

    // Calculate SHA-256 hash
    final digest = sha256.convert(der);

    // Format as colon-separated hex string (e.g., "AB:CD:EF:...")
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(':')
        .toUpperCase();
  }

  /// Download file without certificate verification (HTTP or trusted HTTPS)
  ///
  /// Use this for regular HTTP downloads or when certificate verification
  /// is not needed (e.g., trusted CA-signed certificates)
  static Future<void> downloadUnsecure({
    required String url,
    required String outputPath,
    Function(int, int)? onProgress,
  }) async {
    // Guard: only HTTP(S) is allowed, and HTTPS connections are always
    // validated against the platform trust store (no badCertificateCallback
    // is set here). Prefer downloadWithFingerprint for self-signed peers.
    final parsed = Uri.tryParse(url);
    if (parsed == null ||
        parsed.host.isEmpty ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw ArgumentError('Unsupported or malformed download URL: $url');
    }

    final client = HttpClient();

    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw HttpException(
          'HTTP ${response.statusCode}: Failed to download file',
        );
      }

      final contentLength = response.contentLength;
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      int receivedBytes = 0;
      final stopwatch = Stopwatch()..start();
      const progressUpdateInterval = Duration(milliseconds: 100);

      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        // Report progress with throttling (every 100ms or on completion)
        if (onProgress != null && contentLength > 0) {
          if (receivedBytes == contentLength ||
              stopwatch.elapsed >= progressUpdateInterval) {
            onProgress(receivedBytes, contentLength);
            stopwatch.reset();
          }
        }
      }

      await sink.flush();
      await sink.close();
    } catch (e) {
      final file = File(outputPath);
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close();
    }
  }
}

/// Exception thrown when certificate fingerprint verification fails
class CertificateVerificationException implements Exception {
  final String message;
  final String expectedFingerprint;
  final String actualFingerprint;

  CertificateVerificationException({
    required this.message,
    required this.expectedFingerprint,
    required this.actualFingerprint,
  });

  @override
  String toString() {
    return 'CertificateVerificationException: $message\n'
        'Expected: $expectedFingerprint\n'
        'Actual: $actualFingerprint';
  }
}
