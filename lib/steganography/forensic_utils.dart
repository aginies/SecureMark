import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import '../models/processor_models.dart';

class ForensicUtils {
  /// Calculates a stable hash of the image pixels, optionally excluding bits
  /// used for steganography.
  static String calculateForensicHash(img.Image image,
      {bool excludeAllLSB = false, bool excludeRedLSB = false}) {
    return calculateForensicHashBytes(image,
            excludeAllLSB: excludeAllLSB, excludeRedLSB: excludeRedLSB)
        .toString();
  }

  /// Calculates a stable hash of the image pixels, returning raw bytes.
  static Digest calculateForensicHashBytes(img.Image image,
      {bool excludeAllLSB = false, bool excludeRedLSB = false}) {
    final int width = image.width;
    final int height = image.height;
    final buffer = Uint8List(width * height * 3); // R, G, B
    var idx = 0;
    for (final frame in image.frames) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixel = frame.getPixel(x, y);
          var r = pixel.r.toInt();
          var g = pixel.g.toInt();
          var b = pixel.b.toInt();

          if (excludeAllLSB) {
            r &= 0xFE;
            g &= 0xFE;
            b &= 0xFE;
          } else if (excludeRedLSB) {
            r &= 0xFE; // Clear LSB of Red (where verification link lives)
          }

          buffer[idx++] = r;
          buffer[idx++] = g;
          buffer[idx++] = b;
        }
      }
      break; // Only hash the first frame
    }
    return sha256.convert(buffer);
  }

  static String generateVerificationLink(
      String sig, String cHash, String sHash) {
    return 'securemark://verify?v=1&s=${base64Url.encode(utf8.encode(sig))}&c=$cHash&o=$sHash';
  }

  static VerificationResult? verifyDeepLink(
      String link, String currentContentHash, String currentSourceHash) {
    try {
      if (!link.startsWith('securemark://verify?v=1&')) return null;
      final uri = Uri.parse(link.replaceFirst('securemark://', 'http://'));
      final sigBase64 = uri.queryParameters['s'];
      final originalContentHash = uri.queryParameters['c'];
      final originalSourceHash = uri.queryParameters['o'];

      if (sigBase64 == null ||
          originalContentHash == null ||
          originalSourceHash == null) {
        return null;
      }

      final author = utf8.decode(base64Url.decode(sigBase64));
      final isContentAuthentic = originalContentHash == currentContentHash;
      final isSourceAuthentic = originalSourceHash == currentSourceHash;

      return VerificationResult(
        isContentAuthentic: isContentAuthentic,
        isSourceAuthentic: isSourceAuthentic,
        author: author,
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
