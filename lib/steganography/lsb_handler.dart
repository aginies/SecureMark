import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'encryption_utils.dart';
import '../models/processor_models.dart';
import '../watermark_error.dart';

class LsbHandler {
  static img.Image embedFileIntoImage(
      img.Image image, String fileName, Uint8List fileBytes,
      {String? password, String channel = 'g'}) {
    final bool encrypt = password != null && password.isNotEmpty;
    Uint8List dataToEmbed = fileBytes;
    final crc = EncryptionUtils.crc16(fileBytes);

    if (encrypt) {
      dataToEmbed = EncryptionUtils.encryptBytes(fileBytes, password);
    }

    final filenameBytes = utf8.encode(fileName);
    if (filenameBytes.length > 255) return image;

    final headerBytes = utf8.encode(encrypt ? 'SE' : 'SF');
    final fullPayload = BytesBuilder();
    fullPayload.add(headerBytes);
    fullPayload
        .add([(filenameBytes.length >> 8) & 0xFF, filenameBytes.length & 0xFF]);
    final fileSize = dataToEmbed.length;
    fullPayload.add([
      (fileSize >> 24) & 0xFF,
      (fileSize >> 16) & 0xFF,
      (fileSize >> 8) & 0xFF,
      fileSize & 0xFF
    ]);
    fullPayload.add(filenameBytes);
    fullPayload.add(dataToEmbed);
    fullPayload.add([(crc >> 8) & 0xFF, crc & 0xFF]);

    final payload = fullPayload.toBytes();
    final totalBits = payload.length * 8;
    final int width = image.width;
    final int totalPixels = width * image.height;

    if (totalBits > totalPixels) {
      final maxBits = totalPixels - 64;
      final maxBytes = maxBits ~/ 8;
      final maxFileSize = maxBytes - filenameBytes.length - 2;
      final maxKB = (maxFileSize / 1024).toStringAsFixed(1);
      final actualKB = (fileBytes.length / 1024).toStringAsFixed(1);

      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message:
            'File "$fileName" ($actualKB KB) too large for image ($width×${image.height}). Max: $maxKB KB',
      );
    }

    const int headerBits = 64;
    for (var i = 0; i < headerBits && i < totalBits; i++) {
      final bit = (payload[i ~/ 8] >> (7 - (i % 8))) & 1;
      final pixel = _getPixelAtIndex(image, i, width);
      _setChannelBit(pixel, channel, bit);
    }

    final int remainingBits = totalBits - headerBits;
    if (remainingBits > 0) {
      final int stride =
          _calculateStride(totalPixels - headerBits, remainingBits);
      for (var i = 0; i < remainingBits; i++) {
        final bitIdx = headerBits + i;
        final bit = (payload[bitIdx ~/ 8] >> (7 - (bitIdx % 8))) & 1;
        final pixelIdx = _calculateStridedIndex(headerBits, i, stride);
        if (pixelIdx >= totalPixels) break;
        final pixel = _getPixelAtIndex(image, pixelIdx, width);
        _setChannelBit(pixel, channel, bit);
      }
    }
    return image;
  }

  static img.Image embedLSB(img.Image image, String message,
      {String? password, String channel = 'b'}) {
    if (message.isEmpty) return image;
    final bool encrypt = password != null && password.isNotEmpty;
    final Uint8List originalMessageBytes =
        Uint8List.fromList(utf8.encode(message));
    Uint8List messageBytes = originalMessageBytes;
    final crc = EncryptionUtils.crc16(originalMessageBytes);

    if (encrypt) {
      messageBytes =
          EncryptionUtils.encryptBytes(originalMessageBytes, password);
    }

    final headerBytes = utf8.encode(encrypt ? 'SX' : 'SM');
    final fullPayload = BytesBuilder();
    fullPayload.add(headerBytes);
    final length = messageBytes.length;
    fullPayload.add([
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF
    ]);
    fullPayload.add(messageBytes);
    fullPayload.add([(crc >> 8) & 0xFF, crc & 0xFF]);

    final payload = fullPayload.toBytes();
    final totalBits = payload.length * 8;
    final int width = image.width;
    final int totalPixels = width * image.height;

    if (totalBits > totalPixels) return image;

    const int headerBits = 48;
    for (var i = 0; i < headerBits && i < totalBits; i++) {
      final bit = (payload[i ~/ 8] >> (7 - (i % 8))) & 1;
      final pixel = _getPixelAtIndex(image, i, width);
      _setChannelBit(pixel, channel, bit);
    }

    final int remainingBits = totalBits - headerBits;
    if (remainingBits > 0) {
      final int stride =
          _calculateStride(totalPixels - headerBits, remainingBits);
      for (var i = 0; i < remainingBits; i++) {
        final bitIdx = headerBits + i;
        final bit = (payload[bitIdx ~/ 8] >> (7 - (bitIdx % 8))) & 1;
        final pixelIdx = _calculateStridedIndex(headerBits, i, stride);
        if (pixelIdx >= totalPixels) break;
        final pixel = _getPixelAtIndex(image, pixelIdx, width);
        _setChannelBit(pixel, channel, bit);
      }
    }
    return image;
  }

  static String? extractTextFromImage(
      img.Image image, bool isEncrypted, String? password,
      {String channel = 'b', bool checkHeader = true}) {
    try {
      final int width = image.width;
      final int totalPixels = width * image.height;
      final List<int> bytes = <int>[];
      var currentByte = 0;

      // 1. Extract Header (first 16 bits = 2 bytes)
      for (var i = 0; i < 16; i++) {
        final pixel = _getPixelAtIndex(image, i, width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }

      final header = utf8.decode(bytes);
      if (checkHeader && header != 'SM' && header != 'SX') {
        return null;
      }

      // 2. Extract Length (next 32 bits = 4 bytes)
      bytes.clear();
      for (var i = 16; i < 48; i++) {
        final pixel = _getPixelAtIndex(image, i, width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }

      final int payloadLength =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      if (payloadLength <= 0 || payloadLength > 1024 * 1024) {
        return null;
      }

      final int totalDataBytes = payloadLength + 2; // +2 for CRC
      final int remainingPixels = totalPixels - 48;
      if (totalDataBytes * 8 > remainingPixels) {
        return null;
      }

      // 3. Extract Payload
      final int stride = _calculateStride(remainingPixels, totalDataBytes * 8);
      currentByte = 0;
      bytes.clear();
      for (var i = 0; i < totalDataBytes * 8; i++) {
        final pixelIdx = _calculateStridedIndex(48, i, stride);
        final pixel = _getPixelAtIndex(image, pixelIdx, width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }

      Uint8List payloadBytes =
          Uint8List.fromList(bytes.sublist(0, payloadLength));
      final extractedCrc =
          (bytes[payloadLength] << 8) | bytes[payloadLength + 1];

      bool encryptedFound = header == 'SX';

      if (encryptedFound) {
        if (password == null || password.isEmpty) {
          return '[ENCRYPTED] (Password required)';
        }
        final decrypted = EncryptionUtils.decryptBytes(payloadBytes, password);
        if (decrypted == null) {
          return '[ENCRYPTED] (Wrong password)';
        }
        payloadBytes = decrypted;
      }

      if (EncryptionUtils.crc16(payloadBytes) != extractedCrc) {
        return encryptedFound ? '[ENCRYPTED] (Wrong password)' : null;
      }

      return utf8.decode(payloadBytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static ExtractedFileResult? extractFileFromImage(
      img.Image image, bool isEncrypted, String? password,
      {String channel = 'g'}) {
    try {
      final int width = image.width;
      final int totalPixels = width * image.height;
      final List<int> bytes = <int>[];
      var currentByte = 0;
      for (var i = 16; i < 64; i++) {
        final pixel = _getPixelAtIndex(image, i, width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }
      final int filenameLength = (bytes[0] << 8) | bytes[1];
      final int fileSize =
          (bytes[2] << 24) | (bytes[3] << 16) | (bytes[4] << 8) | bytes[5];

      if (filenameLength <= 0 ||
          filenameLength > 255 ||
          fileSize <= 0 ||
          fileSize > 50 * 1024 * 1024) {
        return null;
      }
      final int totalDataBytes = filenameLength + fileSize + 2;
      final int remainingPixels = totalPixels - 64;
      if (totalDataBytes * 8 > remainingPixels) {
        return null;
      }
      final int stride = _calculateStride(remainingPixels, totalDataBytes * 8);
      currentByte = 0;
      bytes.clear();
      for (var i = 0; i < totalDataBytes * 8; i++) {
        final pixelIdx = _calculateStridedIndex(64, i, stride);
        final pixel = _getPixelAtIndex(image, pixelIdx, width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }
      final filename =
          utf8.decode(bytes.sublist(0, filenameLength), allowMalformed: true);
      Uint8List fileBytes = Uint8List.fromList(
          bytes.sublist(filenameLength, filenameLength + fileSize));
      final extractedCrc = (bytes[filenameLength + fileSize] << 8) |
          bytes[filenameLength + fileSize + 1];

      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        final decrypted = EncryptionUtils.decryptBytes(fileBytes, password);
        if (decrypted == null) {
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        fileBytes = decrypted;
      }
      final calculatedCrc = EncryptionUtils.crc16(fileBytes);

      if (calculatedCrc != extractedCrc) {
        return isEncrypted
            ? ExtractedFileResult(
                fileName: filename, fileBytes: Uint8List(0), isEncrypted: true)
            : null;
      }
      return ExtractedFileResult(
          fileName: filename, fileBytes: fileBytes, isEncrypted: isEncrypted);
    } catch (_) {
      return null;
    }
  }

  /// Encrypts a hidden file for embedding in PDF metadata
  static Uint8List encryptHiddenFileForPdf(
      String fileName, Uint8List fileBytes, String? password) {
    final filenameBytes = utf8.encode(fileName);
    if (filenameBytes.length > 255) {
      throw const WatermarkError(
          type: WatermarkErrorType.processingTimeout,
          message: 'Filename too long for PDF metadata embedding');
    }

    final crc = EncryptionUtils.crc16(fileBytes);
    final builder = BytesBuilder();

    // Format: [nameLen(2)] [name] [fileSize(4)] [fileBytes] [crc(2)]
    builder
        .add([(filenameBytes.length >> 8) & 0xFF, filenameBytes.length & 0xFF]);
    builder.add(filenameBytes);
    builder.add([
      (fileBytes.length >> 24) & 0xFF,
      (fileBytes.length >> 16) & 0xFF,
      (fileBytes.length >> 8) & 0xFF,
      fileBytes.length & 0xFF
    ]);
    builder.add(fileBytes);
    builder.add([(crc >> 8) & 0xFF, crc & 0xFF]);

    final payload = builder.toBytes();

    // Encrypt if password provided
    if (password != null && password.isNotEmpty) {
      return EncryptionUtils.encryptBytes(payload, password);
    }
    return payload;
  }

  static ExtractedFileResult? decryptHiddenFileFromPdf(
      Uint8List encData, String? pw) {
    try {
      final d = (pw?.isNotEmpty == true)
          ? EncryptionUtils.decryptBytes(encData, pw!)
          : encData;
      if (d == null || d.length < 8) return null;
      final nL = (d[0] << 8) | d[1];
      if (d.length < 6 + nL) return null;
      final n = utf8.decode(d.sublist(2, 2 + nL));
      final fS =
          (d[2 + nL] << 24) | (d[3 + nL] << 16) | (d[4 + nL] << 8) | d[5 + nL];
      if (d.length < 6 + nL + fS + 2) return null;
      final f = d.sublist(6 + nL, 6 + nL + fS);
      final crc = (d[6 + nL + fS] << 8) | d[6 + nL + fS + 1];
      return EncryptionUtils.crc16(f) == crc
          ? ExtractedFileResult(
              fileName: n, fileBytes: f, isEncrypted: pw?.isNotEmpty == true)
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Encrypts a signature for embedding in PDF metadata
  static Uint8List encryptSignatureForPdf(String signature, String? password) {
    final sigBytes = utf8.encode(signature);
    final crc = EncryptionUtils.crc16(sigBytes);
    final builder = BytesBuilder();

    // Format: [header(2)] [reserved(2)] [length(4)] [sigBytes] [crc(2)]
    // Header: 'SX' for encrypted, 'ST' for plaintext
    final isEncrypted = password != null && password.isNotEmpty;
    final header = isEncrypted ? 'SX' : 'ST';
    builder.add(utf8.encode(header));
    builder.add([0x00, 0x00]); // Reserved bytes

    Uint8List dataToEmbed = sigBytes;
    if (isEncrypted) {
      dataToEmbed = EncryptionUtils.encryptBytes(sigBytes, password);
    }

    builder.add([
      (dataToEmbed.length >> 24) & 0xFF,
      (dataToEmbed.length >> 16) & 0xFF,
      (dataToEmbed.length >> 8) & 0xFF,
      dataToEmbed.length & 0xFF
    ]);
    builder.add(dataToEmbed);
    builder.add([(crc >> 8) & 0xFF, crc & 0xFF]);

    return builder.toBytes();
  }

  /// Calculates stride for LSB pixel distribution
  /// Ensures even distribution across available pixels with safe clamping
  static int _calculateStride(int availablePixels, int requiredBits) {
    return (availablePixels ~/ requiredBits).clamp(1, 1000);
  }

  /// Converts linear pixel index to (x, y) coordinates and returns pixel
  static img.Pixel _getPixelAtIndex(img.Image image, int index, int width) {
    return image.getPixel(index % width, index ~/ width);
  }

  /// Calculates strided pixel index from header offset
  static int _calculateStridedIndex(
      int headerOffset, int iteration, int stride) {
    return headerOffset + (iteration * stride);
  }

  static int _getChannelBit(img.Pixel p, String c) =>
      (c == 'r'
              ? p.r
              : c == 'g'
                  ? p.g
                  : p.b)
          .toInt() &
      1;

  static void _setChannelBit(img.Pixel p, String c, int b) {
    if (c == 'r') {
      p.r = (p.r.toInt() & ~1) | b;
    } else if (c == 'g') {
      p.g = (p.g.toInt() & ~1) | b;
    } else {
      p.b = (p.b.toInt() & ~1) | b;
    }
  }
}
