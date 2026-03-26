import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../font_manager.dart';
import '../qr_config.dart';
import '../steganography/lsb_handler.dart';
import '../steganography/forensic_utils.dart';
import 'color_utils.dart';
import 'identity_manager.dart';
import 'watermark_utils.dart';

// Constants for watermark placement
const double _angleStepDegrees = 15;
const int _randomColorPoolSize = 6;

// Shared Random instance for consistent randomness
final Random _random = Random();

/// Represents a watermark placement with all necessary properties
class _Placement {
  const _Placement({
    required this.x,
    required this.y,
    required this.fontSize,
    required this.angle,
    required this.colorKey,
    required this.color,
    required this.font,
  });

  final int x;
  final int y;
  final int fontSize;
  final double angle;
  final int colorKey;
  final img.Color color;
  final WatermarkFont font;
}

/// Represents a resolved color with its key for caching
class _ResolvedColor {
  const _ResolvedColor({
    required this.key,
    required this.color,
  });

  final int key;
  final img.Color color;
}

class WatermarkFieldHandler {
  static Future<String?> applyWatermarkField(
    img.Image image,
    String text,
    double transparency,
    double density,
    bool useRandomColor,
    int selectedColorValue,
    double fontSize,
    WatermarkFont font,
    Map<String, Uint8List>? stamps, {
    double antiAiLevel = 0.0,
    QrWatermarkConfig? qrConfig,
    bool digitallySign = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    void Function(double, String)? onProgress,
  }) async {
    final width = image.width;
    final height = image.height;
    final alpha = _alphaFromTransparency(transparency);

    if (transparency < 100) {
      if (watermarkType == WatermarkType.text) {
        // Use advanced placement algorithm for text watermarks
        final placements = _buildPlacements(
            width: width,
            height: height,
            watermarkText: text,
            transparency: transparency,
            density: density,
            useRandomColor: useRandomColor,
            selectedColorValue: selectedColorValue,
            fontSize: fontSize.round(),
            font: font,
            onProgress: onProgress,
            progressStart: 0.0,
            progressEnd: 0.85);

        // Stamp cache: key = 'angle-colorKey' or 'angle-colorKey-jitter' for Anti-AI
        final stampCache = <String, img.Image>{};

        // For Anti-AI: pre-generate jitter variants to avoid repeated cloning
        // Quantize jitter levels to increase cache hits: -2, -1, 0, +1, +2
        final jitterLevels = antiAiLevel > 0 ? [-2, -1, 0, 1, 2] : [0];
        final maxJitter = (antiAiLevel / 100.0) * 40;

        var stampIndex = 0;
        final totalStamps = placements.length;

        for (final placement in placements) {
          // Position jitter for Anti-AI
          final jitterX =
              ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                  .round();
          final jitterY =
              ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                  .round();

          // Select random jitter level for Anti-AI
          final jitterLevel = antiAiLevel > 0
              ? jitterLevels[_random.nextInt(jitterLevels.length)]
              : 0;

          // Extended cache key includes jitter level for Anti-AI
          final cacheKey = antiAiLevel > 0
              ? '${placement.angle.round()}-${placement.colorKey}-$jitterLevel'
              : '${placement.angle.round()}-${placement.colorKey}';

          // Get or create cached stamp (with jitter variant if Anti-AI enabled)
          final stamp = stampCache.putIfAbsent(cacheKey, () {
            final baseStamp = _buildWatermarkStamp(text, placement, stamps);

            // Apply quantized alpha jitter if Anti-AI enabled
            if (antiAiLevel > 0 && jitterLevel != 0) {
              final jitteredStamp = baseStamp.clone();
              final alphaJitter = (jitterLevel * maxJitter / 2).round();

              // Apply uniform jitter to all non-transparent pixels
              for (final pixel in jitteredStamp) {
                if (pixel.a > 0) {
                  pixel.a = (pixel.a + alphaJitter).clamp(0, 255).toInt();
                }
              }
              return jitteredStamp;
            }
            return baseStamp;
          });

          img.compositeImage(image, stamp,
              dstX: placement.x + jitterX,
              dstY: placement.y + jitterY,
              blend: img.BlendMode.alpha);

          // Report progress every 5 stamps to avoid excessive callbacks
          stampIndex++;
          if (stampIndex % 5 == 0 && onProgress != null) {
            final progress = 0.85 + (stampIndex / totalStamps) * 0.13;
            final message = antiAiLevel > 0
                ? 'Applying watermarks with Anti-AI protection... ($stampIndex/$totalStamps)'
                : 'Applying watermarks... ($stampIndex/$totalStamps)';
            onProgress(progress, message);
          }
        }

        // Report completion of watermark application
        if (onProgress != null && totalStamps > 0) {
          final message = antiAiLevel > 0
              ? 'Watermarks applied with Anti-AI protection'
              : 'Watermarks applied';
          onProgress(0.98, message);
        }
      } else if (watermarkType == WatermarkType.image &&
          watermarkImageBytes != null) {
        // Logo watermarks use simpler grid-based placement
        final logo = img.decodeImage(watermarkImageBytes);
        if (logo != null) {
          // Resize logo based on fontSize (treating fontSize as target height)
          final resizedLogo = img.copyResize(logo, height: fontSize.round());

          // Ensure logo has alpha channel (important for JPEGs)
          final scaledLogo = resizedLogo.numChannels == 4
              ? resizedLogo
              : resizedLogo.convert(numChannels: 4);

          // Apply transparency to the logo
          final alphaFactor = alpha / 255.0;
          for (final pixel in scaledLogo) {
            pixel.a = (pixel.a * alphaFactor).round();
          }

          // Grid-based placement for logos
          final targetCount = _watermarkCount(width, height, density);
          final columns =
              max(2, sqrt(targetCount * (width / max(1, height))).round());
          final rows = max(2, (targetCount / columns).ceil());
          final cellWidth = width / columns.toDouble();
          final cellHeight = height / rows.toDouble();

          var logoIndex = 0;
          final totalLogos = rows * columns;

          for (var row = 0; row < rows; row++) {
            for (var col = 0; col < columns; col++) {
              final x = (col * cellWidth) +
                  (_random.nextDouble() * (cellWidth * 0.3));
              final y = (row * cellHeight) +
                  (_random.nextDouble() * (cellHeight * 0.3));

              img.compositeImage(image, scaledLogo,
                  dstX: x.toInt(), dstY: y.toInt(), blend: img.BlendMode.alpha);

              logoIndex++;
              // Report progress every 5 logos
              if (logoIndex % 5 == 0 && onProgress != null) {
                final progress = 0.85 + (logoIndex / totalLogos) * 0.13;
                onProgress(progress,
                    'Applying logo watermarks... ($logoIndex/$totalLogos)');
              }
            }
          }

          // Report completion
          if (onProgress != null && totalLogos > 0) {
            onProgress(0.98, 'Logo watermarks applied');
          }
        }
      }
    }

    // Digital Signing (Integrity)
    String? integrityText;
    String? signature;
    String? publicKey;
    if (digitallySign) {
      onProgress?.call(0.99, 'Digitally signing document...');
      // Use forensic hash excluding ALL LSBs so visual integrity is independent of steganography
      final hash =
          ForensicUtils.calculateForensicHashBytes(image, excludeAllLSB: true);
      signature = await IdentityManager.signData(hash.bytes);
      publicKey = await IdentityManager.getDevicePublicKey();
      IdentityManager.onLog?.call('Digital signature generated for image.');

      // Always embed in Red LSB channel so analyzer can find it without QR scanning
      // (Red is used for Integrity/Forensic, Blue for normal LSB text, Green for files)
      integrityText = 'SecureMarkIntegrity:$signature SecureMarkKey:$publicKey';
      LsbHandler.embedLSB(image, integrityText, channel: 'r');
    }

    // Add QR code if enabled
    if (qrConfig != null && qrConfig.visibleQr) {
      // Update config with integrity info if available
      final finalConfig = signature != null
          ? qrConfig.copyWith(integrity: signature, publicKey: publicKey)
          : qrConfig;

      final qrImg = WatermarkUtils.generateQrCodeImage(
          data: finalConfig.toQrString(), size: finalConfig.size.round());
      final (qrX, qrY) = WatermarkUtils.calculateQrPosition(
          imageWidth: width,
          imageHeight: height,
          qrSize: finalConfig.size.round(),
          position: finalConfig.position);

      // Apply opacity to QR
      for (final p in qrImg) {
        p.a = (p.a * finalConfig.opacity).round();
      }

      img.compositeImage(image, qrImg, dstX: qrX, dstY: qrY);
    }

    return integrityText;
  }

  static int _watermarkCount(int w, int h, double d) =>
      max(8, ((w * h / 18000) * 2.69 * (d / 50).clamp(0.4, 2.0)).round());

  /// Builds placements for text watermarks using advanced algorithm
  static List<_Placement> _buildPlacements({
    required int width,
    required int height,
    required String watermarkText,
    required double transparency,
    required double density,
    required bool useRandomColor,
    required int selectedColorValue,
    required int fontSize,
    required WatermarkFont font,
    void Function(double, String)? onProgress,
    double progressStart = 0.0,
    double progressEnd = 1.0,
  }) {
    final targetCount = _watermarkCount(width, height, density);
    final colorPool = _buildColorPool(useRandomColor, selectedColorValue,
        _alphaFromTransparency(transparency));
    final columns =
        max(2, sqrt(targetCount * (width / max(1, height))).round());
    final rows = max(2, (targetCount / columns).ceil());
    final cellWidth = width / columns.toDouble();
    final cellHeight = height / rows.toDouble();
    final cells =
        List.generate(rows * columns, (i) => Point(i % columns, i ~/ columns))
          ..shuffle(_random);
    final placements = <_Placement>[];

    // Allocate 80% of progress range to cell iteration, 20% to extra attempts
    final cellProgressRange = (progressEnd - progressStart) * 0.8;
    final extraProgressRange = (progressEnd - progressStart) * 0.2;

    var cellIndex = 0;
    for (final cell in cells) {
      if (placements.length >= targetCount) break;
      final p = _tryPlacementInCell(
          width: width,
          height: height,
          watermarkText: watermarkText,
          cellColumn: cell.x,
          cellRow: cell.y,
          cellWidth: cellWidth,
          cellHeight: cellHeight,
          colorPool: colorPool,
          fontSize: fontSize,
          font: font);
      if (p != null) placements.add(p);

      // Report progress every 10 cells to avoid excessive callbacks
      cellIndex++;
      if (cellIndex % 10 == 0 && onProgress != null) {
        final progress =
            progressStart + (cellIndex / cells.length) * cellProgressRange;
        onProgress(progress,
            'Calculating placements... (${placements.length}/$targetCount)');
      }
    }

    var extra = targetCount * 4;
    final totalExtra = extra;
    while (placements.length < targetCount && extra-- > 0) {
      final p = _tryPlacementAnywhere(
          width: width,
          height: height,
          watermarkText: watermarkText,
          colorPool: colorPool,
          fontSize: fontSize,
          font: font);
      if (p != null) placements.add(p);

      // Report progress every 20 extra attempts
      if ((totalExtra - extra) % 20 == 0 && onProgress != null) {
        final extraProgress = (totalExtra - extra) / totalExtra;
        final progress = progressStart +
            cellProgressRange +
            (extraProgress * extraProgressRange);
        onProgress(progress,
            'Optimizing placements... (${placements.length}/$targetCount)');
      }
    }
    return placements;
  }

  /// Tries to place a watermark in a specific cell
  static _Placement? _tryPlacementInCell({
    required int width,
    required int height,
    required String watermarkText,
    required int cellColumn,
    required int cellRow,
    required double cellWidth,
    required double cellHeight,
    required List<_ResolvedColor> colorPool,
    required int fontSize,
    required WatermarkFont font,
  }) {
    for (var i = 0; i < 6; i++) {
      final angle = _randomAngle();
      final size = _rotatedStampSize(watermarkText, fontSize, angle);
      if (size.$1 >= width || size.$2 >= height) continue;
      final minX = (cellColumn * cellWidth).floor();
      final maxX = min(width - 1, ((cellColumn + 1) * cellWidth).floor() - 1);
      final minY = (cellRow * cellHeight).floor();
      final maxY = min(height - 1, ((cellRow + 1) * cellHeight).floor() - 1);
      final rMinX = max(-size.$1 + 1, minX - (size.$1 ~/ 3));
      final rMinY = max(-size.$2 + 1, minY - (size.$2 ~/ 3));
      if (maxX < rMinX || maxY < rMinY) continue;
      final x = rMinX + _random.nextInt(maxX - rMinX + 1);
      final y = rMinY + _random.nextInt(maxY - rMinY + 1);
      final color = _pickColor(colorPool);
      return _Placement(
          x: x,
          y: y,
          fontSize: fontSize,
          angle: angle,
          colorKey: color.key,
          color: color.color,
          font: font);
    }
    return null;
  }

  /// Tries to place a watermark anywhere in the image
  static _Placement? _tryPlacementAnywhere({
    required int width,
    required int height,
    required String watermarkText,
    required List<_ResolvedColor> colorPool,
    required int fontSize,
    required WatermarkFont font,
  }) {
    for (var i = 0; i < 12; i++) {
      final angle = _randomAngle();
      final size = _rotatedStampSize(watermarkText, fontSize, angle);
      if (size.$1 >= width || size.$2 >= height) continue;
      final x = _random.nextInt(width + size.$1) - size.$1 + 1;
      final y = _random.nextInt(height + size.$2) - size.$2 + 1;
      final color = _pickColor(colorPool);
      return _Placement(
          x: x,
          y: y,
          fontSize: fontSize,
          angle: angle,
          colorKey: color.key,
          color: color.color,
          font: font);
    }
    return null;
  }

  /// Builds a watermark stamp for a placement with optional TTF rendering
  static img.Image _buildWatermarkStamp(String watermarkText,
      _Placement placement, Map<String, Uint8List>? preRenderedStamps) {
    final baseTextWidth =
        max(1, (watermarkText.length * 18 * (placement.fontSize / 24)).round());
    final baseTextHeight = (48 * (placement.fontSize / 24)).round();
    final textImage =
        img.Image(width: baseTextWidth, height: baseTextHeight, numChannels: 4);
    textImage.clear(img.ColorRgba8(0, 0, 0, 0));

    final stampKey = '${placement.font.fontFamily}-${placement.fontSize}';
    if (preRenderedStamps != null && preRenderedStamps.containsKey(stampKey)) {
      final ttfStamp = img.decodePng(preRenderedStamps[stampKey]!);
      if (ttfStamp != null) {
        final colorized = img.Image.from(ttfStamp);
        for (final pixel in colorized) {
          if (pixel.a > 0) {
            pixel.r = placement.color.r;
            pixel.g = placement.color.g;
            pixel.b = placement.color.b;
            pixel.a = (pixel.a * (placement.color.a / 255.0)).round();
          }
        }
        img.compositeImage(textImage, colorized,
            dstX: max(0, (baseTextWidth - colorized.width) ~/ 2),
            dstY: max(0, (baseTextHeight - colorized.height) ~/ 2),
            blend: img.BlendMode.alpha);
      } else {
        _drawBitmapText(textImage, watermarkText, placement);
      }
    } else {
      _drawBitmapText(textImage, watermarkText, placement);
    }
    final rotated = img.copyRotate(textImage,
        angle: placement.angle, interpolation: img.Interpolation.linear);
    rotated.backgroundColor = img.ColorRgba8(0, 0, 0, 0);
    return rotated;
  }

  static void _drawBitmapText(
      img.Image textImage, String watermarkText, _Placement placement) {
    final bitmapFont = placement.font.isBitmap
        ? placement.font.getBitmapFont(placement.fontSize)
        : _getFontForSize(placement.fontSize);
    if (bitmapFont != null) {
      img.drawString(textImage, watermarkText,
          font: bitmapFont,
          x: 0,
          y: (12 * (placement.fontSize / 24)).round(),
          color: placement.color);
    }
  }

  static img.BitmapFont _getFontForSize(int fontSize) {
    if (fontSize <= 18) return img.arial14;
    if (fontSize <= 32) return img.arial24;
    return img.arial48;
  }

  /// Calculates rotated stamp size (bounding box after rotation)
  static (int, int) _rotatedStampSize(String text, int fontSize, double angle) {
    final s = fontSize / 24.0;
    final w = max(1, (text.length * 18 * s).round());
    final h = (48 * s).round();
    final r = angle * pi / 180.0;
    return (
      (w * cos(r).abs() + h * sin(r).abs()).ceil(),
      (w * sin(r).abs() + h * cos(r).abs()).ceil()
    );
  }

  /// Builds a color pool for consistent random colors
  static List<_ResolvedColor> _buildColorPool(bool rnd, int val, int a) => rnd
      ? List.generate(_randomColorPoolSize,
          (i) => _ResolvedColor(key: i, color: _randomWatermarkColor(a)))
      : [
          _ResolvedColor(
              key: (a << 24) | (val & 0xFFFFFF),
              color: _resolveWatermarkColor(false, val, a))
        ];

  /// Picks a random color from the pool
  static _ResolvedColor _pickColor(List<_ResolvedColor> pool) =>
      pool[_random.nextInt(pool.length)];

  /// Generates a random watermark color using HSV
  static img.Color _randomWatermarkColor(int a) {
    final (r, g, b) = ColorUtils.hsvToRgb(random: _random);
    return img.ColorRgba8(r, g, b, a);
  }

  /// Resolves watermark color (random or selected)
  static img.Color _resolveWatermarkColor(bool rnd, int val, int a) => rnd
      ? _randomWatermarkColor(a)
      : img.ColorRgba8((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF, a);

  /// Generates a random angle in 15-degree steps
  static double _randomAngle() =>
      _random.nextInt((360 / _angleStepDegrees).round()) * _angleStepDegrees;

  /// Converts transparency to alpha value
  static int _alphaFromTransparency(double t) =>
      t >= 100 ? 0 : ((100 - t) / 100 * 255).round();
}
