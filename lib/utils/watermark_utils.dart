import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import '../qr_config.dart';
import '../watermark_error.dart';
import 'package:qr/qr.dart';

class WatermarkUtils {
  /// Strips everything a user-supplied file prefix must not contain.
  ///
  /// The prefix is a plain filename fragment: it must never be able to
  /// change the directory part of the output path (path traversal via
  /// `../`), select a drive (Windows `:`), or carry null/control
  /// characters — whatever its origin (settings field, imported config
  /// zip, saved profile).
  static String sanitizeFilePrefix(String prefix) {
    return prefix.replaceAll(RegExp(r'[/\\:\u0000-\u001f\u007f]'), '');
  }

  /// Strips a client-supplied file name down to a safe basename.
  ///
  /// A name can arrive from an `x-file-name` header, a `Content-Disposition`
  /// header, or a URL path. It must never be able to escape its target
  /// directory (`..`, absolute paths, Windows drive/separators) or inject an
  /// HTTP header (CR/LF/controls/quotes).
  static String sanitizeFileName(String name) {
    var sanitized = name.replaceAll(RegExp(r'[\\:\u0000-\u001f\u007f"]'), '_');
    sanitized = p.basename(sanitized);
    sanitized = sanitized.replaceAll('/', '_').trim();
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'file';
    }
    return sanitized;
  }

  static String outputPath(String path, String ext,
      [bool ts = false, String pref = 'securemark-']) {
    String s = '';
    if (ts) {
      final n = DateTime.now();
      s = '-${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}-${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
    }
    // Sanitize here (not only in the UI) so every caller — including
    // values restored from an imported config — is safe.
    return p.join(p.dirname(path),
        '${sanitizeFilePrefix(pref)}${p.basenameWithoutExtension(path)}$s$ext');
  }

  /// Resolves the watermark text by appending the current date and time.
  ///
  /// This timestamp is always part of the visible watermark and is
  /// independent of the includeTimestamp flag, which only gates the timestamp
  /// in the output filename (see outputPath) — matching the UI label
  /// "Include Date & Hour in Filename".
  static String resolvedWatermarkText(String t) {
    final n = DateTime.now();
    final d =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final s =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
    return t.trim().isEmpty ? '$d $s' : '${t.trim()} $d $s';
  }

  static img.Image resizeToTarget(img.Image image, int? targetSize) {
    if (targetSize == null) {
      return image;
    }
    final width = image.width;
    final height = image.height;
    if (width <= targetSize && height <= targetSize) {
      return image;
    }

    double ratio;
    if (width > height) {
      ratio = targetSize / width;
    } else {
      ratio = targetSize / height;
    }

    final newWidth = (width * ratio).round();
    final newHeight = (height * ratio).round();

    return img.copyResize(image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average);
  }

  static Future<bool> isSupportedFile(File file) async {
    final type = await detectFileType(file);
    return ['.jpg', '.jpeg', '.png', '.webp', '.pdf', '.heic', '.heif']
        .contains(type);
  }

  /// Detects the actual file type from the header bytes.
  ///
  /// A known extension is returned as-is; otherwise the header is sniffed.
  /// If the file cannot be read, throws [WatermarkError]
  /// ([WatermarkErrorType.fileCorrupted]) instead of silently falling back to
  /// the raw extension: the extension of an unreadable file is an unverified
  /// guess, and treating it as a detection can mis-identify the format.
  static Future<String> detectFileType(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (['.pdf', '.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif']
        .contains(extension)) {
      return extension;
    }

    if (!await file.exists()) {
      return extension;
    }

    final List<int> header;
    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        header = await raf.read(12);
      } finally {
        await raf.close();
      }
    } catch (e) {
      // An unreadable file is not evidence about its format: fail explicitly
      // rather than guessing from the extension.
      if (e is WatermarkError) rethrow;
      throw WatermarkError(
        type: WatermarkErrorType.fileCorrupted,
        message: 'Could not read file header',
        filePath: file.path,
        originalError: e,
      );
    }

    if (header.length >= 4) {
      if (header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46) {
        return '.pdf';
      }
      if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
        return '.jpg';
      }
      if (header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47) {
        return '.png';
      }
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return '.webp';
    }
    if (header.length >= 12) {
      final ftyp = String.fromCharCodes(header.sublist(4, 8));
      if (ftyp == 'ftyp') {
        final brand = String.fromCharCodes(header.sublist(8, 12));
        if (['heic', 'heix', 'hevc', 'mif1', 'msf1'].contains(brand)) {
          return '.heic';
        }
      }
    }
    return extension;
  }

  static Uint8List encodeImageInOriginalFormat(
      img.Image i, String ext, int q, bool fPng) {
    if (fPng || ext == '.png') {
      return Uint8List.fromList(img.encodePng(i));
    }
    if (ext == '.webp') {
      return Uint8List.fromList(img.encodePng(i));
    }
    return Uint8List.fromList(img.encodeJpg(i, quality: q));
  }

  static img.Image? generateHeatmapImage(
      img.Image original, img.Image processed) {
    if (original.width != processed.width ||
        original.height != processed.height) {
      return null;
    }
    final width = original.width;
    final height = original.height;
    final heatmap = img.Image(width: width, height: height);

    // Optimized: Use iterators instead of getPixel/setPixel (3-5x faster)
    final originalIter = original.iterator;
    final processedIter = processed.iterator;
    int x = 0, y = 0;

    while (originalIter.moveNext() && processedIter.moveNext()) {
      final originalPixel = originalIter.current;
      final processedPixel = processedIter.current;

      if (originalPixel.r != processedPixel.r ||
          originalPixel.g != processedPixel.g ||
          originalPixel.b != processedPixel.b) {
        heatmap.setPixelRgb(x, y, 255, 0, 0);
      } else {
        heatmap.setPixelRgb(x, y, (originalPixel.r * 0.3).toInt(),
            (originalPixel.g * 0.3).toInt(), (originalPixel.b * 0.3).toInt());
      }

      // Update coordinates
      x++;
      if (x >= width) {
        x = 0;
        y++;
      }
    }
    return heatmap;
  }

  static img.Image generateQrCodeImage(
      {required String data, required int size}) {
    try {
      final qrCode =
          QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.H);
      final qrImage = QrImage(qrCode);
      final moduleCount = qrImage.moduleCount;
      if (moduleCount == 0) {
        return img.Image(width: size, height: size, numChannels: 4);
      }
      final image = img.Image(width: size, height: size, numChannels: 4);
      image.clear(img.ColorRgba8(255, 255, 255, 255));
      final moduleSize = size / moduleCount;
      for (var y = 0; y < moduleCount; y++) {
        for (var x = 0; x < moduleCount; x++) {
          if (qrImage.isDark(y, x)) {
            final px = (x * moduleSize).round();
            final py = (y * moduleSize).round();
            final endX = ((x + 1) * moduleSize).round();
            final endY = ((y + 1) * moduleSize).round();
            for (var iy = py; iy < endY && iy < size; iy++) {
              for (var ix = px; ix < endX && ix < size; ix++) {
                image.setPixel(ix, iy, img.ColorRgba8(0, 0, 0, 255));
              }
            }
          }
        }
      }
      return image;
    } catch (e) {
      return img.Image(width: size, height: size, numChannels: 4);
    }
  }

  static (int, int) calculateQrPosition(
      {required int imageWidth,
      required int imageHeight,
      required int qrSize,
      required QrPosition position}) {
    const margin = 20;
    return switch (position) {
      QrPosition.topLeft => (margin, margin),
      QrPosition.topRight => (imageWidth - qrSize - margin, margin),
      QrPosition.bottomLeft => (margin, imageHeight - qrSize - margin),
      QrPosition.bottomRight => (
          imageWidth - qrSize - margin,
          imageHeight - qrSize - margin
        ),
      QrPosition.center => (
          (imageWidth - qrSize) ~/ 2,
          (imageHeight - qrSize) ~/ 2
        ),
    };
  }
}
