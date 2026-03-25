import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart'
    show TextPainter, TextSpan, TextAlign, TextDirection, FontWeight;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync;
import 'package:qr/qr.dart';
import 'package:encrypt/encrypt.dart' as enc;

import 'font_manager.dart';
import 'qr_config.dart';

final Random _random = Random();
const double _angleStepDegrees = 15;
const int _randomColorPoolSize = 6;
const int _maxFileSize = 100 * 1024 * 1024; // 100MiB

/// Specific error types for better error handling
enum WatermarkErrorType {
  unsupportedFileType,
  fileTooLarge,
  fileNotFound,
  fileCorrupted,
  invalidImageData,
  invalidPdfData,
  memoryLimitExceeded,
  processingTimeout,
  operationCancelled,
  unknownError,
}

class WatermarkError implements Exception {
  const WatermarkError({
    required this.type,
    required this.message,
    this.filePath,
    this.originalError,
  });

  final WatermarkErrorType type;
  final String message;
  final String? filePath;
  final Object? originalError;

  @override
  String toString() {
    final buffer = StringBuffer('WatermarkError: $message');
    if (filePath != null) {
      buffer.write(' (File: ${p.basename(filePath!)})');
    }
    if (originalError != null) {
      buffer.write(' - Original error: $originalError');
    }
    return buffer.toString();
  }

  /// Get user-friendly error message
  String get userMessage {
    // Check for specific steganography capacity error
    if (message.contains('too large to hide')) {
      return message;
    }

    switch (type) {
      case WatermarkErrorType.unsupportedFileType:
        return 'This file type is not supported. Please use JPG, PNG, or PDF files.';
      case WatermarkErrorType.fileTooLarge:
        return 'File is too large (max ${(_maxFileSize / (1024 * 1024)).round()}MB). Please use a smaller file.';
      case WatermarkErrorType.fileNotFound:
        return 'File not found. Please make sure the file exists.';
      case WatermarkErrorType.fileCorrupted:
        return 'File appears to be corrupted or unreadable.';
      case WatermarkErrorType.invalidImageData:
        return 'Invalid image data. The image file may be corrupted.';
      case WatermarkErrorType.invalidPdfData:
        return 'Invalid PDF data. The PDF file may be corrupted.';
      case WatermarkErrorType.memoryLimitExceeded:
        return 'Not enough memory to process this file. Try using a smaller file.';
      case WatermarkErrorType.processingTimeout:
        return 'Processing took too long and was cancelled. Try using a smaller file.';
      case WatermarkErrorType.operationCancelled:
        return 'Operation was cancelled.';
      case WatermarkErrorType.unknownError:
        return 'An unexpected error occurred while processing the file.';
    }
  }
}

class ProcessResult {
  const ProcessResult({
    required this.outputPath,
    required this.outputBytes,
    required this.previewBytes,
    required this.originalBytes,
    this.heatmapBytes,
    this.steganographyVerified = false,
    this.robustVerified = false,
    this.isPdf = false,
  });

  final String outputPath;
  final Uint8List outputBytes;
  final Uint8List? previewBytes;
  final Uint8List? originalBytes;
  final Uint8List? heatmapBytes;
  final bool steganographyVerified;
  final bool robustVerified;
  final bool isPdf;
}

class ExtractedFileResult {
  const ExtractedFileResult({
    required this.fileName,
    required this.fileBytes,
    this.isEncrypted = false,
  });

  final String fileName;
  final Uint8List fileBytes;
  final bool isEncrypted;
}

class VerificationResult {
  const VerificationResult({
    required this.isContentAuthentic,
    required this.isSourceAuthentic,
    required this.author,
    required this.timestamp,
    this.messageKey,
  });

  final bool isContentAuthentic;
  final bool isSourceAuthentic;
  final String author;
  final DateTime timestamp;
  final String? messageKey;

  bool get isAuthentic => isContentAuthentic || isSourceAuthentic;
}

class AnalysisResult {
  const AnalysisResult({
    this.signature,
    this.robustSignature,
    this.file,
    this.verification,
  });

  final String? signature;
  final String? robustSignature;
  final ExtractedFileResult? file;
  final VerificationResult? verification;
}

/// Progress callback for reporting processing progress
typedef ProgressCallback = void Function(double progress, String message);

/// Cancellation token for cancelling operations
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class _ValidationResult {
  const _ValidationResult({
    required this.isValid,
    this.error,
    this.pageCount = 0,
  });

  final bool isValid;
  final WatermarkError? error;
  final int pageCount;
}

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

class _ResolvedColor {
  const _ResolvedColor({
    required this.key,
    required this.color,
  });

  final int key;
  final img.Color color;
}

class WatermarkProcessor {
  /// Generate a heatmap highlighting differences between two images
  static Uint8List? generateHeatmap(Uint8List original, Uint8List processed) {
    try {
      final img.Image? originalImg = img.decodeImage(original);
      final img.Image? processedImg = img.decodeImage(processed);

      if (originalImg == null || processedImg == null) return null;

      // Ensure they are the same size
      if (originalImg.width != processedImg.width ||
          originalImg.height != processedImg.height) {
        return null;
      }

      final width = originalImg.width;
      final height = originalImg.height;
      final heatmap = img.Image(width: width, height: height);

      // We want to highlight differences.
      // Background will be a dimmed version of the original image
      // Differences will be bright red
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final originalPixel = originalImg.getPixel(x, y);
          final processedPixel = processedImg.getPixel(x, y);

          final r1 = originalPixel.r;
          final g1 = originalPixel.g;
          final b1 = originalPixel.b;

          final r2 = processedPixel.r;
          final g2 = processedPixel.g;
          final b2 = processedPixel.b;

          // Simple difference threshold
          if ((r1 - r2).abs() > 0 ||
              (g1 - g2).abs() > 0 ||
              (b1 - b2).abs() > 0) {
            // Highlight difference in bright red
            heatmap.setPixel(x, y, img.ColorRgb8(255, 0, 0));
          } else {
            // Dim original pixel for context
            heatmap.setPixel(
                x,
                y,
                img.ColorRgb8(
                  (r1 * 0.3).toInt(),
                  (g1 * 0.3).toInt(),
                  (b1 * 0.3).toInt(),
                ));
          }
        }
      }

      return Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
    } catch (e) {
      debugPrint('Error generating heatmap: $e');
      return null;
    }
  }

  /// Cache for processed results to avoid reprocessing identical requests
  static final Map<String, ProcessResult> _resultCache =
      <String, ProcessResult>{};

  /// Maximum cache size to prevent memory issues
  static const int _maxCacheSize = 10;

  /// Check if a file is supported based on extension or magic bytes
  static Future<bool> isSupportedFile(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    const supportedExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.pdf',
      '.heic',
      '.heif'
    };

    if (supportedExtensions.contains(extension)) {
      return true;
    }

    // If extension is not recognized, check magic bytes
    try {
      if (!await file.exists()) return false;
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();

      if (header.length < 4) return false;

      // JPEG: FF D8 FF
      if (header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF) {
        return true;
      }

      // PNG: 89 50 4E 47
      if (header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47) {
        return true;
      }

      // PDF: %PDF-
      if (header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46) {
        return true;
      }

      // WebP: RIFF .... WEBP
      if (header.length >= 12 &&
          header[0] == 0x52 &&
          header[1] == 0x49 &&
          header[2] == 0x46 &&
          header[3] == 0x46 &&
          header[8] == 0x57 &&
          header[9] == 0x45 &&
          header[10] == 0x42 &&
          header[11] == 0x50) {
        return true;
      }

      // HEIC: .... ftypheic or ftypmif1
      if (header.length >= 12) {
        final ftyp = String.fromCharCodes(header.sublist(4, 8));
        if (ftyp == 'ftyp') {
          final brand = String.fromCharCodes(header.sublist(8, 12));
          if (['heic', 'heix', 'hevc', 'mif1', 'msf1'].contains(brand)) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Process a file with comprehensive error handling and validation
  static Future<ProcessResult> processFile({
    required File file,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    WatermarkFont font = WatermarkFont.arial,
    int jpegQuality = 75,
    int? targetSize,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    bool rasterizePdf = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    // Check for cancellation at the start
    if (cancellationToken?.isCancelled == true) {
      throw const WatermarkError(
        type: WatermarkErrorType.operationCancelled,
        message: 'Operation was cancelled before processing started',
      );
    }

    onProgress?.call(0.0, 'progressValidating');

    // Validate the file
    final validation = await _validateFile(file);
    if (!validation.isValid) {
      throw validation.error!;
    }

    // Check cache
    final cacheKey = _generateCacheKey(
      file.path,
      transparency,
      density,
      watermarkText,
      useRandomColor,
      selectedColorValue,
      fontSize,
      font,
      jpegQuality,
      targetSize,
      includeTimestamp,
      preserveMetadata,
      rasterizePdf,
      filePrefix,
      antiAiLevel,
      useSteganography,
      useRobustSteganography,
      useAiCloaking,
      watermarkType,
      watermarkImageBytes,
      steganographyPassword,
      steganographyText,
      hiddenFileName,
      hiddenFileBytes,
      qrConfig,
    );

    if (_resultCache.containsKey(cacheKey)) {
      onProgress?.call(1.0, 'progressFromCache');
      return _resultCache[cacheKey]!;
    }

    try {
      onProgress?.call(0.05, 'progressDetectingType');

      final detectedType = await detectFileType(file);
      final extension = detectedType.isEmpty
          ? p.extension(file.path).toLowerCase()
          : detectedType;

      onProgress?.call(0.1, 'progressStarting');
      final resolvedText = _resolvedWatermarkText(watermarkText);

      ProcessResult result;
      if (extension == '.pdf') {
        result = await _processPdf(
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: resolvedText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          includeTimestamp: includeTimestamp,
          preserveMetadata: preserveMetadata,
          rasterizePdf: rasterizePdf,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: (progress, message) {
            // Map 0.0-1.0 from _processPdf to 0.1-0.9
            onProgress?.call(0.1 + (progress * 0.8), message);
          },
          cancellationToken: cancellationToken,
        );
      } else if (extension == '.jpg' ||
          extension == '.jpeg' ||
          extension == '.png' ||
          extension == '.webp') {
        result = await _processImage(
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: resolvedText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          targetSize: targetSize,
          includeTimestamp: includeTimestamp,
          preserveMetadata: preserveMetadata,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: (progress, message) {
            // Map 0.0-1.0 from _processImage to 0.1-0.9
            onProgress?.call(0.1 + (progress * 0.8), message);
          },
          cancellationToken: cancellationToken,
        );
      } else {
        throw WatermarkError(
          type: WatermarkErrorType.unsupportedFileType,
          message: 'Unsupported file type: $extension',
          filePath: file.path,
        );
      }

      // Cache the result (with size limit)
      _addToCache(cacheKey, result);

      onProgress?.call(1.0, 'progressComplete');
      return result;
    } catch (e) {
      if (e is WatermarkError) {
        rethrow;
      }
      throw WatermarkError(
        type: WatermarkErrorType.unknownError,
        message: 'Unexpected error during processing',
        filePath: file.path,
        originalError: e,
      );
    }
  }

  /// Validate a file before processing
  static Future<_ValidationResult> _validateFile(File file) async {
    try {
      // Check if file exists
      if (!await file.exists()) {
        return _ValidationResult(
          isValid: false,
          error: WatermarkError(
            type: WatermarkErrorType.fileNotFound,
            message: 'File does not exist',
            filePath: file.path,
          ),
        );
      }

      // Check file size
      final fileSize = await file.length();
      if (fileSize > _maxFileSize) {
        return _ValidationResult(
          isValid: false,
          error: WatermarkError(
            type: WatermarkErrorType.fileTooLarge,
            message:
                'File size ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB exceeds limit of ${(_maxFileSize / (1024 * 1024)).round()}MB',
            filePath: file.path,
          ),
        );
      }

      // Check if file is supported
      if (!await isSupportedFile(file)) {
        final extension = p.extension(file.path).toLowerCase();
        return _ValidationResult(
          isValid: false,
          error: WatermarkError(
            type: WatermarkErrorType.unsupportedFileType,
            message: 'Unsupported file format or extension: $extension',
            filePath: file.path,
          ),
        );
      }

      // Basic file integrity check - try to read first few bytes
      try {
        final bytes = await file.openRead(0, 1024).first;
        if (bytes.isEmpty) {
          return _ValidationResult(
            isValid: false,
            error: WatermarkError(
              type: WatermarkErrorType.fileCorrupted,
              message: 'File appears to be empty',
              filePath: file.path,
            ),
          );
        }
      } catch (e) {
        return _ValidationResult(
          isValid: false,
          error: WatermarkError(
            type: WatermarkErrorType.fileCorrupted,
            message: 'Unable to read file',
            filePath: file.path,
            originalError: e,
          ),
        );
      }

      int pageCount = 0;
      final detectedType = await detectFileType(file);
      if (detectedType == '.pdf') {
        try {
          final pdfBytes = await file.readAsBytes();
          final document = sync.PdfDocument(inputBytes: pdfBytes);
          pageCount = document.pages.count;
          document.dispose();
        } catch (_) {
          // Ignore errors here, they will be caught during actual processing
        }
      }

      return _ValidationResult(isValid: true, pageCount: pageCount);
    } catch (e) {
      return _ValidationResult(
        isValid: false,
        error: WatermarkError(
          type: WatermarkErrorType.unknownError,
          message: 'Error during file validation',
          filePath: file.path,
          originalError: e,
        ),
      );
    }
  }

  /// Detect file type based on extension or magic bytes
  static Future<String> detectFileType(File file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (['.pdf'].contains(extension)) return '.pdf';
    if (['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif']
        .contains(extension)) {
      return extension;
    }

    // Fallback to magic bytes
    try {
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(12);
      await raf.close();

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
    } catch (_) {}

    return extension;
  }

  /// Generate cache key for result caching
  static String _generateCacheKey(
    String filePath,
    double transparency,
    double density,
    String watermarkText,
    bool useRandomColor,
    int selectedColorValue,
    double fontSize,
    WatermarkFont font,
    int jpegQuality,
    int? targetSize,
    bool includeTimestamp,
    bool preserveMetadata,
    bool rasterizePdf,
    String filePrefix,
    double antiAiLevel,
    bool useSteganography,
    bool useRobustSteganography,
    bool useAiCloaking,
    WatermarkType watermarkType,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
  ) {
    final hiddenFileHash =
        hiddenFileBytes != null ? hiddenFileBytes.length.toString() : 'none';
    final watermarkImageHash = watermarkImageBytes != null
        ? watermarkImageBytes.length.toString()
        : 'none';
    final qrHash = qrConfig != null
        ? '${qrConfig.visibleQr}-${qrConfig.author}-${qrConfig.url}-${qrConfig.position}-${qrConfig.size}'
        : 'none';
    return '$filePath-$transparency-$density-$watermarkText-$useRandomColor-$selectedColorValue-$fontSize-${font.fontFamily}-$jpegQuality-$targetSize-$includeTimestamp-$preserveMetadata-$rasterizePdf-$filePrefix-$antiAiLevel-$useSteganography-$useRobustSteganography-$useAiCloaking-$watermarkType-$watermarkImageHash-$steganographyPassword-$steganographyText-$hiddenFileName-$hiddenFileHash-$qrHash';
  }

  /// Add result to cache with size management
  static void _addToCache(String key, ProcessResult result) {
    if (_resultCache.length >= _maxCacheSize) {
      // Remove oldest entry
      final firstKey = _resultCache.keys.first;
      _resultCache.remove(firstKey);
    }
    _resultCache[key] = result;
  }

  /// Clear the result cache
  static void clearCache() {
    _resultCache.clear();
  }

  static Future<ProcessResult> _processImage({
    required File file,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    try {
      onProgress?.call(0.0, 'progressReadingImage');

      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Operation cancelled during image reading',
        );
      }

      final inputBytes = await file.readAsBytes();
      final extension = p.extension(file.path).toLowerCase();

      // Pre-render TTF stamps if using non-bitmap fonts
      Map<String, Uint8List>? preRenderedStamps;
      if (watermarkType == WatermarkType.text && !font.isBitmap) {
        onProgress?.call(0.1, 'progressRenderingFont');
        final stampKey = '${font.fontFamily}-${fontSize.round()}';
        try {
          final stampBytes = await _renderTextWithFlutterCanvas(
            text: watermarkText,
            font: font,
            fontSize: fontSize.round(),
            color: const ui.Color.fromARGB(
                255, 255, 255, 255), // White base, will be colorized
          );
          preRenderedStamps = {stampKey: stampBytes};
        } catch (e) {
          debugPrint('TTF pre-rendering failed, will use bitmap fallback: $e');
        }
      }

      // Determine the message based on what operations will be performed
      final operations = <String>[];
      if (transparency < 100) operations.add('watermarks');
      if (antiAiLevel > 0) operations.add('Anti-AI protection');
      if (useAiCloaking) operations.add('AI cloaking');
      if (qrConfig?.visibleQr == true) operations.add('QR code');
      if (useSteganography) operations.add('invisible signatures');
      if (useRobustSteganography) operations.add('robust watermark');
      final operationText = operations.isEmpty
          ? 'Processing'
          : 'Applying ${operations.join(", ")}';
      // We don't localize this composite operation text easily, so we keep it as a base
      onProgress?.call(0.1, '$operationText...');

      final receivePort = ReceivePort();
      receivePort.listen((message) {
        if (message is Map<String, dynamic>) {
          onProgress?.call(message['progress'], message['message']);
        }
      });

      final progressSendPort = receivePort.sendPort;

      Uint8List outputBytes;
      Uint8List? heatmapBytes;
      try {
        final isolateResult = await _runImageIsolate(
          inputBytes: inputBytes,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          targetSize: targetSize,
          filePath: file.path,
          originalExtension: extension,
          preserveMetadata: preserveMetadata,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          preRenderedStamps: preRenderedStamps,
          progressPort: progressSendPort,
        );
        outputBytes = isolateResult['output']!;
        heatmapBytes = isolateResult['heatmap'];
      } finally {
        receivePort.close();
      }

      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Operation cancelled during image processing',
        );
      }

      onProgress?.call(0.85, 'progressFinalizingImage');

      // For HEIC/HEIF or other formats, we might want to default to .jpg for the output
      // since our encoder handles them as such or as PNG.
      var outputExtension = extension;
      if (extension == '.heic' || extension == '.heif') {
        outputExtension = '.jpg';
      }

      final outputPath =
          _outputPath(file.path, outputExtension, includeTimestamp, filePrefix);

      // Verify steganography if enabled
      bool verified = false;
      bool robustVerified = false;
      if (useSteganography ||
          useRobustSteganography ||
          hiddenFileName != null) {
        onProgress?.call(0.9, 'progressVerifyingStegano');

        // Use the new combined analyzer for verification
        final analysis =
            analyzeImage(outputBytes, password: steganographyPassword);

        final expectedSignature =
            (steganographyText != null && steganographyText.isNotEmpty)
                ? steganographyText
                : watermarkText;

        if (useSteganography || hiddenFileName != null) {
          bool allVerified = true;
          if (hiddenFileName != null) {
            allVerified &= (analysis.file != null &&
                analysis.file!.fileName == hiddenFileName);
          }
          if (useSteganography) {
            allVerified &=
                (analysis.signature?.startsWith(expectedSignature) ?? false);
          }
          verified = allVerified;
        }

        if (useRobustSteganography) {
          robustVerified =
              analysis.robustSignature?.startsWith(expectedSignature) ?? false;
        }

        if (verified || robustVerified) {
          onProgress?.call(0.95, 'progressSteganoVerified');
        } else {
          onProgress?.call(0.95, 'progressSteganoFailed');
        }
      }

      onProgress?.call(1.0, 'progressComplete');

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: outputBytes,
        originalBytes: inputBytes, // Store original bytes for A/B comparison
        heatmapBytes: heatmapBytes,
        steganographyVerified: verified,
        robustVerified: robustVerified,
        isPdf: false,
      );
    } catch (e) {
      if (e is WatermarkError) {
        rethrow;
      }
      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message: 'Failed to process image',
        filePath: file.path,
        originalError: e,
      );
    }
  }

  static Future<ProcessResult> _processPdf({
    required File file,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    bool rasterizePdf = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final inputBytes = await file.readAsBytes();

      if (rasterizePdf) {
        onProgress?.call(0.2, 'Rasterizing PDF (flattening)...');
        return await _processPdfRasterFallback(
          inputBytes: inputBytes,
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          includeTimestamp: includeTimestamp,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          useAiCloaking: useAiCloaking,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
      }

      onProgress?.call(0.1, 'Reading PDF file...');

      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Operation cancelled',
        );
      }

      onProgress?.call(0.2, 'Adding watermark layer (background)...');

      final receivePort = ReceivePort();
      receivePort.listen((message) {
        if (message is Map<String, dynamic>) {
          onProgress?.call(message['progress'], message['message']);
        }
      });

      final progressSendPort = receivePort.sendPort;

      // Move heavy PDF processing to Isolate
      Uint8List outputBytes;
      try {
        outputBytes = await _runPdfIsolate(
          inputBytes: inputBytes,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          preserveMetadata: preserveMetadata,
          antiAiLevel: antiAiLevel,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          qrConfig: qrConfig,
          useAiCloaking: useAiCloaking,
          steganographyPassword: steganographyPassword,
          useSteganography: useSteganography,
          steganographyText: steganographyText,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          progressPort: progressSendPort,
        );
      } catch (e, stackTrace) {
        debugPrint('Vector engine error: $e');
        debugPrint('Stack trace: $stackTrace');
        onProgress?.call(
            0.3, 'Vector engine failed ($e), falling back to raster engine...');
        // Fallback to raster engine for malformed PDFs
        return await _processPdfRasterFallback(
          inputBytes: inputBytes,
          file: file,
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          font: font,
          jpegQuality: jpegQuality,
          includeTimestamp: includeTimestamp,
          filePrefix: filePrefix,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          watermarkType: watermarkType,
          watermarkImageBytes: watermarkImageBytes,
          steganographyPassword: steganographyPassword,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
      } finally {
        receivePort.close();
      }

      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Operation cancelled during PDF processing',
        );
      }

      onProgress?.call(0.9, 'Finalizing PDF...');

      final outputPath =
          _outputPath(file.path, '.pdf', includeTimestamp, filePrefix);

      // Generate a preview of the first page of the OUTPUT
      final preview =
          await Printing.raster(outputBytes, pages: [0], dpi: 72).first;
      final previewBytes = await preview.toPng();

      // Generate a preview of the first page of the ORIGINAL for comparison
      final originalPreview =
          await Printing.raster(inputBytes, pages: [0], dpi: 72).first;
      final originalBytesImage = await originalPreview.toPng();

      // Generate heatmap for the first page
      Uint8List? heatmapBytes;
      try {
        final originalImg = img.decodeImage(originalBytesImage);
        final processedImg = img.decodeImage(previewBytes);
        if (originalImg != null && processedImg != null) {
          final heatmap = _generateHeatmapImage(originalImg, processedImg);
          if (heatmap != null) {
            heatmapBytes =
                Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
          }
        }
      } catch (e) {
        debugPrint('Failed to generate PDF heatmap: $e');
      }

      // Verify steganography if enabled
      bool verified = false;
      if (useSteganography) {
        try {
          final analysis = await analyzeFileAsync(outputBytes, outputPath,
              password: steganographyPassword);
          if (analysis.signature != null || analysis.file != null) {
            verified = true;
          }
        } catch (e) {
          debugPrint('PDF Steganography verification failed: $e');
        }
      }

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: previewBytes,
        originalBytes: originalBytesImage,
        heatmapBytes: heatmapBytes,
        steganographyVerified: verified,
        isPdf: true,
      );
    } catch (e) {
      if (e is WatermarkError) rethrow;
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'Failed to process PDF with vector engine',
        filePath: file.path,
        originalError: e,
      );
    }
  }

  static Uint8List _renderWatermarkedPdfBytes({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    QrWatermarkConfig? qrConfig,
    bool useAiCloaking = false,
    String? steganographyPassword,
    bool useSteganography = false,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    SendPort? progressPort,
  }) {
    sync.PdfDocument document;
    try {
      progressPort
          ?.send({'progress': 0.1, 'message': 'Parsing PDF document...'});
      document = sync.PdfDocument(inputBytes: inputBytes);
    } catch (e) {
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'The PDF file appears to be malformed or corrupted. Error: $e',
        originalError: e,
      );
    }

    if (!preserveMetadata) {
      document.documentInformation.author = '';
      document.documentInformation.creator =
          'SecureMark (https://github.com/aginies/SecureMark)';
      document.documentInformation.keywords = 'SecureMark, Watermark, Security';
      document.documentInformation.producer = 'SecureMark';
      document.documentInformation.subject = '';
      document.documentInformation.title = '';
    } else {
      if (document.documentInformation.creator.isEmpty) {
        document.documentInformation.creator =
            'SecureMark (https://github.com/aginies/SecureMark)';
      }
    }

    final pageCount = document.pages.count;
    final alpha = (100 - transparency) / 100.0;
    final pdfFont =
        sync.PdfStandardFont(sync.PdfFontFamily.helvetica, fontSize);

    // --- Steganography & Hidden Data Implementation ---
    List<int>? signatureBits;
    if (useSteganography) {
      String keywords = document.documentInformation.keywords;
      if (keywords.isNotEmpty && !keywords.endsWith(' ')) {
        keywords += ' ';
      }

      // 1. Hidden File Embedding
      if (hiddenFileName != null && hiddenFileBytes != null) {
        try {
          final encryptedData = _encryptFileForSteganography(
            fileName: hiddenFileName,
            fileBytes: hiddenFileBytes,
            password: steganographyPassword,
          );
          final base64Data = base64Encode(encryptedData);
          keywords += 'SecureMarkHidden:$base64Data ';
        } catch (e) {
          debugPrint('Error embedding hidden file in PDF: $e');
        }
      }

      // 2. Encrypted Text Signature (Vector LSB Carrier)
      final signature =
          steganographyText != null && steganographyText.isNotEmpty
              ? steganographyText
              : watermarkText;

      final bool encrypt =
          steganographyPassword != null && steganographyPassword.isNotEmpty;
      final Uint8List originalBytes = Uint8List.fromList(utf8.encode(signature));
      Uint8List payloadBytes = originalBytes;

      if (encrypt) {
        payloadBytes = _encryptBytes(originalBytes, steganographyPassword);
      }

      // Format: [Type 'SM' or 'SX'] [Len 4 bytes] [Payload] [CRC 2 bytes]
      final builder = BytesBuilder();
      builder.add(utf8.encode(encrypt ? 'SX' : 'SM'));
      builder.add([
        (payloadBytes.length >> 24) & 0xFF,
        (payloadBytes.length >> 16) & 0xFF,
        (payloadBytes.length >> 8) & 0xFF,
        payloadBytes.length & 0xFF,
      ]);
      builder.add(payloadBytes);
      final crc = _crc16(originalBytes);
      builder.add([(crc >> 8) & 0xFF, crc & 0xFF]);

      final fullPayload = builder.toBytes();
      signatureBits = _bytesToBits(fullPayload);

      // Metadata backup for robustness (Keywords storage)
      final encodedPayload = base64Encode(fullPayload);
      keywords += 'SecureMarkSig:$encodedPayload ';

      document.documentInformation.keywords = keywords.trim();
    }

    sync.PdfBitmap? logoBitmap;
    if (watermarkType == WatermarkType.image && watermarkImageBytes != null) {
      logoBitmap = sync.PdfBitmap(watermarkImageBytes);
    }

    var currentBitIndex = 0;

    for (var i = 0; i < pageCount; i++) {
      final page = document.pages[i];
      final pageSize = page.size;
      final graphics = page.graphics;

      // Apply AI Cloaking to the page if enabled using a vector-based adversarial pattern
      if (useAiCloaking) {
        graphics.save();
        for (var j = 0; j < 100; j++) {
          final x = _random.nextDouble() * pageSize.width;
          final y = _random.nextDouble() * pageSize.height;
          final size = 2.0 + _random.nextDouble() * 3.0;
          graphics.setTransparency(0.02 + _random.nextDouble() * 0.03);
          final color = _randomWatermarkColor(255);
          graphics.drawEllipse(ui.Rect.fromLTWH(x, y, size, size),
              brush: sync.PdfSolidBrush(sync.PdfColor(
                  color.r.toInt(), color.g.toInt(), color.b.toInt())));
        }
        graphics.restore();
      }

      final targetCount = _watermarkCount(
          pageSize.width.toInt(), pageSize.height.toInt(), density);
      final columns = max<int>(
          2,
          sqrt(targetCount *
                  (pageSize.width / max<double>(1.0, pageSize.height)))
              .round());
      final rows = max<int>(2, (targetCount / columns).ceil());

      final cellWidth = pageSize.width / columns;
      final cellHeight = pageSize.height / rows;

      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          graphics.save();
          final color =
              _resolveSyncfusionColor(useRandomColor, selectedColorValue);
          final brush = sync.PdfSolidBrush(color);

          final jitterX = (antiAiLevel / 100.0) *
              (cellWidth * 0.2) *
              (_random.nextDouble() - 0.5);
          final jitterY = (antiAiLevel / 100.0) *
              (cellHeight * 0.2) *
              (_random.nextDouble() - 0.5);

          final x = (col * cellWidth) +
              (_random.nextDouble() * (cellWidth * 0.3)) +
              jitterX;
          final y = (row * cellHeight) +
              (_random.nextDouble() * (cellHeight * 0.3)) +
              jitterY;

          graphics.save();
          graphics.translateTransform(x, y);

          if (watermarkType == WatermarkType.text) {
            final jitterAngle =
                (antiAiLevel / 100.0) * 15.0 * (_random.nextDouble() - 0.5);
            final angle = _randomAngle() + jitterAngle;
            graphics.rotateTransform(angle);
            graphics.setTransparency(alpha);

            if (signatureBits != null) {
              // Vector LSB: Draw character by character with subtle color offsets
              double currentX = 0;
              for (var charIdx = 0; charIdx < watermarkText.length; charIdx++) {
                final char = watermarkText[charIdx];
                final charWidth = pdfFont.measureString(char).width;

                // Get bit to hide
                final bit = signatureBits[currentBitIndex % signatureBits.length];
                currentBitIndex++;

                // Subtle color offset in Blue channel (Vector LSB)
                // We ensure it stays in 0-255 range
                final r = color.r;
                final g = color.g;
                final b = (color.b % 2 == bit)
                    ? color.b
                    : (color.b > 128 ? color.b - 1 : color.b + 1);

                final charBrush = sync.PdfSolidBrush(sync.PdfColor(r, g, b));
                graphics.drawString(char, pdfFont,
                    brush: charBrush, bounds: ui.Rect.fromLTWH(currentX, 0, 0, 0));
                currentX += charWidth;
              }
            } else {
              graphics.drawString(watermarkText, pdfFont, brush: brush);
            }
          } else if (logoBitmap != null) {
            // Logos are no longer rotated per user request
            graphics.setTransparency(alpha);
            final aspectRatio = logoBitmap.width / logoBitmap.height;
            final logoWidth = fontSize * aspectRatio;
            graphics.drawImage(
              logoBitmap,
              ui.Rect.fromLTWH(0, 0, logoWidth, fontSize),
            );
          }

          graphics.restore();
        }
      }

      // Add QR code if configured
      if (qrConfig != null && qrConfig.visibleQr) {
        final qrSize = qrConfig.size;
        final qrData = _buildQrMetadata(qrConfig);

        // Generate QR code image
        final qrImage =
            _generateQrCodeImage(data: qrData, size: qrSize.round());
        final qrPngBytes = Uint8List.fromList(img.encodePng(qrImage));
        final qrBitmap = sync.PdfBitmap(qrPngBytes);

        // Calculate QR position on page
        final (qrX, qrY) = _calculateQrPosition(
          imageWidth: pageSize.width.toInt(),
          imageHeight: pageSize.height.toInt(),
          qrSize: qrSize.round(),
          position: qrConfig.position,
        );

        // Draw QR code with opacity
        graphics.save();
        graphics.setTransparency(qrConfig.opacity);
        graphics.drawImage(
          qrBitmap,
          ui.Rect.fromLTWH(qrX.toDouble(), qrY.toDouble(), qrSize, qrSize),
        );
        graphics.restore();
      }
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<Map<String, Uint8List>> _runImageIsolate({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    required String filePath,
    required String originalExtension,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Map<String, Uint8List>? preRenderedStamps,
    SendPort? progressPort,
  }) {
    return Isolate.run(
      () => _renderWatermarkedImageBytesWithValidation(
        inputBytes: inputBytes,
        transparency: transparency,
        density: density,
        watermarkText: watermarkText,
        useRandomColor: useRandomColor,
        selectedColorValue: selectedColorValue,
        fontSize: fontSize,
        font: font,
        jpegQuality: jpegQuality,
        targetSize: targetSize,
        filePath: filePath,
        originalExtension: originalExtension,
        preserveMetadata: preserveMetadata,
        antiAiLevel: antiAiLevel,
        useSteganography: useSteganography,
        useRobustSteganography: useRobustSteganography,
        useAiCloaking: useAiCloaking,
        watermarkType: watermarkType,
        watermarkImageBytes: watermarkImageBytes,
        steganographyPassword: steganographyPassword,
        steganographyText: steganographyText,
        hiddenFileName: hiddenFileName,
        hiddenFileBytes: hiddenFileBytes,
        qrConfig: qrConfig,
        preRenderedStamps: preRenderedStamps,
        progressPort: progressPort,
      ),
    );
  }

  static Future<Uint8List> _runPdfIsolate({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    QrWatermarkConfig? qrConfig,
    bool useAiCloaking = false,
    String? steganographyPassword,
    bool useSteganography = false,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    SendPort? progressPort,
  }) {
    return Isolate.run(
      () => _renderWatermarkedPdfBytes(
        inputBytes: inputBytes,
        transparency: transparency,
        density: density,
        watermarkText: watermarkText,
        useRandomColor: useRandomColor,
        selectedColorValue: selectedColorValue,
        fontSize: fontSize,
        preserveMetadata: preserveMetadata,
        antiAiLevel: antiAiLevel,
        watermarkType: watermarkType,
        watermarkImageBytes: watermarkImageBytes,
        qrConfig: qrConfig,
        useAiCloaking: useAiCloaking,
        steganographyPassword: steganographyPassword,
        useSteganography: useSteganography,
        steganographyText: steganographyText,
        hiddenFileName: hiddenFileName,
        hiddenFileBytes: hiddenFileBytes,
        progressPort: progressPort,
      ),
    );
  }

  static sync.PdfColor _resolveSyncfusionColor(
      bool useRandomColor, int selectedColorValue) {
    int r, g, b;
    if (useRandomColor) {
      final hue = _random.nextDouble() * 360;
      const double saturation = 0.8;
      const double value = 0.95;
      const double chroma = value * saturation;
      final x = chroma * (1 - (((hue / 60) % 2) - 1).abs());
      const double m = value - chroma;
      double rf, gf, bf;
      if (hue < 60) {
        rf = chroma;
        gf = x;
        bf = 0;
      } else if (hue < 120) {
        rf = x;
        gf = chroma;
        bf = 0;
      } else if (hue < 180) {
        rf = 0;
        gf = chroma;
        bf = x;
      } else if (hue < 240) {
        rf = 0;
        gf = x;
        bf = chroma;
      } else if (hue < 300) {
        rf = x;
        gf = 0;
        bf = chroma;
      } else {
        rf = chroma;
        gf = 0;
        bf = x;
      }
      r = ((rf + m) * 255).round();
      g = ((gf + m) * 255).round();
      b = ((bf + m) * 255).round();
    } else {
      r = (selectedColorValue >> 16) & 0xFF;
      g = (selectedColorValue >> 8) & 0xFF;
      b = selectedColorValue & 0xFF;
    }
    return sync.PdfColor(r, g, b);
  }

  static Map<String, Uint8List> _renderWatermarkedImageBytesWithValidation({
    required Uint8List inputBytes,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    int? targetSize,
    required String filePath,
    required String originalExtension,
    bool preserveMetadata = false,
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Map<String, Uint8List>? preRenderedStamps,
    SendPort? progressPort,
  }) {
    try {
      progressPort
          ?.send({'progress': 0.05, 'message': 'progressDecodingImage'});
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw WatermarkError(
          type: WatermarkErrorType.invalidImageData,
          message: 'Unable to decode image data',
          filePath: filePath,
        );
      }

      final steganographySignature =
          (steganographyText != null && steganographyText.isNotEmpty)
              ? steganographyText
              : watermarkText;

      progressPort
          ?.send({'progress': 0.15, 'message': 'progressResizingImage'});
      final resized = _resizeToTarget(decoded, targetSize);
      final baselineForHeatmap = img.Image.from(resized);
      var outputImage = img.Image.from(resized);

      if (useAiCloaking) {
        progressPort
            ?.send({'progress': 0.25, 'message': 'progressApplyingCloaking'});
        outputImage = _applyAiCloaking(outputImage);
      }

      if (preserveMetadata && !decoded.exif.isEmpty) {
        outputImage.exif = decoded.exif.clone();
      }

      outputImage.textData ??= {};
      outputImage.textData!['Description'] =
          'SecureMark (https://github.com/aginies/SecureMark)';
      outputImage.textData!['Software'] = 'SecureMark';

      progressPort
          ?.send({'progress': 0.35, 'message': 'progressApplyingWatermark'});
      _applyWatermarkField(
        outputImage,
        watermarkText,
        transparency,
        density,
        useRandomColor,
        selectedColorValue,
        fontSize,
        font,
        preRenderedStamps,
        antiAiLevel: antiAiLevel,
        qrConfig: qrConfig,
        watermarkType: watermarkType,
        watermarkImageBytes: watermarkImageBytes,
        onProgress: (progress, message) {
          // Map internal progress (0.0-1.0) to watermark range (0.35-0.75)
          progressPort?.send({
            'progress': 0.35 + (progress * 0.40),
            'message': message,
          });
        },
      );

      if (useRobustSteganography) {
        progressPort
            ?.send({'progress': 0.80, 'message': 'progressEmbeddingRobust'});
        outputImage =
            _embedRobustSignature(outputImage, steganographySignature);
      }

      if (useSteganography) {
        if (hiddenFileName != null && hiddenFileBytes != null) {
          progressPort
              ?.send({'progress': 0.85, 'message': 'progressHidingFile'});
          outputImage = _embedFileIntoImage(
            outputImage,
            hiddenFileName,
            hiddenFileBytes,
            password: steganographyPassword,
            channel:
                'g', // Use Green channel for files to avoid collision with signature
          );
        }
        // Always embed watermark text as LSB if steganography is enabled (Blue channel)
        progressPort
            ?.send({'progress': 0.88, 'message': 'progressEmbeddingLsb'});
        outputImage = _embedLSB(
          outputImage,
          steganographySignature,
          password: steganographyPassword,
          channel: 'b', // Use Blue channel for signature
        );

        // Always embed a Deep-Link Verification seal in the Red channel if steganography is enabled
        // This seals the final pixels with signatures of both content and source.
        final contentHash =
            _calculateForensicHash(outputImage, excludeRedLSB: true);
        final sourceHash =
            _calculateForensicHash(outputImage, excludeAllLSB: true);
        final verificationLink = _generateVerificationLink(
            steganographySignature, contentHash, sourceHash);
        outputImage = _embedLSB(
          outputImage,
          verificationLink,
          password: steganographyPassword,
          channel: 'r', // Use Red channel for verification seal
        );
      }

      progressPort
          ?.send({'progress': 0.90, 'message': 'progressEncodingImage'});
      final forcePng = useSteganography || useRobustSteganography;

      final outputBytes = _encodeImageInOriginalFormat(
          outputImage, originalExtension, jpegQuality, forcePng);

      final result = {'output': outputBytes};

      // Generate heatmap if steganography or AI cloaking is enabled
      if (useSteganography ||
          useRobustSteganography ||
          useAiCloaking ||
          antiAiLevel > 0) {
        progressPort
            ?.send({'progress': 0.95, 'message': 'Generating heatmap...'});
        final heatmap = _generateHeatmapImage(baselineForHeatmap, outputImage);
        if (heatmap != null) {
          result['heatmap'] =
              Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
        }
      }

      return result;
    } catch (e) {
      if (e is WatermarkError) rethrow;
      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message: 'Failed to render watermarked image',
        filePath: filePath,
        originalError: e,
      );
    }
  }

  static img.Image? _generateHeatmapImage(
      img.Image original, img.Image processed) {
    if (original.width != processed.width ||
        original.height != processed.height) {
      return null;
    }

    final width = original.width;
    final height = original.height;
    final heatmap = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final originalPixel = original.getPixel(x, y);
        final processedPixel = processed.getPixel(x, y);

        final r1 = originalPixel.r;
        final g1 = originalPixel.g;
        final b1 = originalPixel.b;

        final r2 = processedPixel.r;
        final g2 = processedPixel.g;
        final b2 = processedPixel.b;

        if ((r1 - r2).abs() > 0 || (g1 - g2).abs() > 0 || (b1 - b2).abs() > 0) {
          heatmap.setPixel(x, y, img.ColorRgb8(255, 0, 0));
        } else {
          heatmap.setPixel(
              x,
              y,
              img.ColorRgb8(
                (r1 * 0.3).toInt(),
                (g1 * 0.3).toInt(),
                (b1 * 0.3).toInt(),
              ));
        }
      }
    }
    return heatmap;
  }

  /// Calculates a stable hash of the image pixels, optionally excluding bits
  /// used for steganography. This ensures verification works even after a
  /// seal is embedded.
  static String _calculateForensicHash(img.Image image,
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
    return sha256.convert(buffer).toString();
  }

  static Future<Uint8List> _renderTextWithFlutterCanvas({
    required String text,
    required WatermarkFont font,
    required int fontSize,
    required ui.Color color,
  }) async {
    final textStyle = font.getTextStyle(
      fontSize: fontSize.toDouble(),
      fontWeight: FontWeight.normal,
    );
    final textSpan =
        TextSpan(text: text, style: textStyle.copyWith(color: color));
    final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    textPainter.layout();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    textPainter.paint(canvas, ui.Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
        textPainter.width.ceil(), textPainter.height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static img.Image _embedFileIntoImage(
      img.Image image, String fileName, Uint8List fileBytes,
      {String? password, String channel = 'g'}) {
    final bool encrypt = password != null && password.isNotEmpty;
    Uint8List dataToEmbed = fileBytes;
    final crc = _crc16(fileBytes);
    debugPrint(
        'File embedding - filename="$fileName", originalSize=${fileBytes.length}, crc=$crc, encrypt=$encrypt');
    if (encrypt) dataToEmbed = _encryptBytes(fileBytes, password);
    final filenameBytes = utf8.encode(fileName);
    if (filenameBytes.length > 255) return image;
    final headerBytes = utf8.encode(encrypt ? 'SE' : 'SF');
    final fullPayload = BytesBuilder();
    fullPayload.add(headerBytes);
    fullPayload
        .add([(filenameBytes.length >> 8) & 0xFF, filenameBytes.length & 0xFF]);
    final fileSize = dataToEmbed.length;
    debugPrint(
        'File embedding - filenameLength=${filenameBytes.length}, encryptedSize=$fileSize, channel=$channel');
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
      // Calculate maximum capacity
      final maxBits = totalPixels - 64; // 64 bits for header
      final maxBytes = maxBits ~/ 8;
      final maxFileSize =
          maxBytes - filenameBytes.length - 2; // minus filename and CRC
      final maxFileSizeKB = (maxFileSize / 1024).toStringAsFixed(1);
      final actualFileSizeKB = (fileBytes.length / 1024).toStringAsFixed(1);
      final imageDimensions = '${image.width}×${image.height}';

      debugPrint('File embedding FAILED - File too large!');
      debugPrint('  Image: $imageDimensions ($totalPixels pixels)');
      debugPrint('  File: $actualFileSizeKB KB');
      debugPrint('  Max capacity: $maxFileSizeKB KB');

      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message:
            'File "$fileName" ($actualFileSizeKB KB) is too large to hide in this image ($imageDimensions). Maximum capacity: $maxFileSizeKB KB',
      );
    }
    const int headerBits = 64;
    for (var i = 0; i < headerBits && i < totalBits; i++) {
      final bit = (payload[i ~/ 8] >> (7 - (i % 8))) & 1;
      final pixel = image.getPixel(i % width, i ~/ width);
      _setChannelBit(pixel, channel, bit);
    }
    final int remainingBits = totalBits - headerBits;
    if (remainingBits > 0) {
      final int stride =
          ((totalPixels - headerBits) ~/ remainingBits).clamp(1, 1000);
      for (var i = 0; i < remainingBits; i++) {
        final bitIdx = headerBits + i;
        final bit = (payload[bitIdx ~/ 8] >> (7 - (bitIdx % 8))) & 1;
        final pixelIdx = headerBits + (i * stride);
        if (pixelIdx >= totalPixels) break;
        final pixel = image.getPixel(pixelIdx % width, pixelIdx ~/ width);
        _setChannelBit(pixel, channel, bit);
      }
    }
    return image;
  }

  static void _setChannelBit(img.Pixel pixel, String channel, int bit) {
    switch (channel) {
      case 'r':
        pixel.r = (pixel.r.toInt() & ~1) | bit;
        break;
      case 'g':
        pixel.g = (pixel.g.toInt() & ~1) | bit;
        break;
      case 'b':
        pixel.b = (pixel.b.toInt() & ~1) | bit;
        break;
      default:
        pixel.b = (pixel.b.toInt() & ~1) | bit;
    }
  }

  static int _getChannelBit(img.Pixel pixel, String channel) {
    switch (channel) {
      case 'r':
        return pixel.r.toInt() & 1;
      case 'g':
        return pixel.g.toInt() & 1;
      case 'b':
        return pixel.b.toInt() & 1;
      default:
        return pixel.b.toInt() & 1;
    }
  }

  static img.Image _embedLSB(img.Image image, String message,
      {String? password, String channel = 'b'}) {
    if (message.isEmpty) return image;
    final bool encrypt = password != null && password.isNotEmpty;
    final Uint8List originalMessageBytes =
        Uint8List.fromList(utf8.encode(message));
    Uint8List messageBytes = originalMessageBytes;
    final crc = _crc16(originalMessageBytes);
    if (encrypt) messageBytes = _encryptBytes(originalMessageBytes, password);
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
      final pixel = image.getPixel(i % width, i ~/ width);
      _setChannelBit(pixel, channel, bit);
    }
    final int remainingBits = totalBits - headerBits;
    if (remainingBits > 0) {
      final int stride =
          ((totalPixels - headerBits) ~/ remainingBits).clamp(1, 1000);
      for (var i = 0; i < remainingBits; i++) {
        final bitIdx = headerBits + i;
        final bit = (payload[bitIdx ~/ 8] >> (7 - (bitIdx % 8))) & 1;
        final pixelIdx = headerBits + (i * stride);
        if (pixelIdx >= totalPixels) break;
        final pixel = image.getPixel(pixelIdx % width, pixelIdx ~/ width);
        _setChannelBit(pixel, channel, bit);
      }
    }
    return image;
  }

  static Future<AnalysisResult> analyzeFileAsync(
      Uint8List bytes, String fileName,
      {String? password}) async {
    final ext = p.extension(fileName).toLowerCase();

    if (ext == '.pdf') {
      // 1. First try Vector-based analysis (Keywords & Vector LSB)
      final vectorResult = await _analyzePdfVector(bytes, password: password);
      if (vectorResult.signature != null || vectorResult.file != null) {
        return vectorResult;
      }

      // 2. Fallback to raster-based analysis if vector finds nothing
      try {
        await for (final page in Printing.raster(bytes, dpi: 150, pages: [0])) {
          final png = await page.toPng();
          return await analyzeImageAsync(png, password: password);
        }
      } catch (e) {
        debugPrint('Error analyzing PDF: $e');
      }
      return const AnalysisResult();
    } else {
      return await analyzeImageAsync(bytes, password: password);
    }
  }

  static Future<AnalysisResult> _analyzePdfVector(Uint8List bytes,
      {String? password}) async {
    try {
      final sync.PdfDocument document = sync.PdfDocument(inputBytes: bytes);
      final keywords = document.documentInformation.keywords;

      String? signature;
      ExtractedFileResult? file;

      // Robust parsing of Keywords string
      final parts = keywords.split(' ');
      for (final part in parts) {
        if (file == null && part.startsWith('SecureMarkHidden:')) {
          final base64Data = part.substring('SecureMarkHidden:'.length);
          try {
            final encryptedData = base64Decode(base64Data);
            file = _decryptFileFromSteganography(encryptedData, password);
          } catch (_) {}
        }

        if (signature == null && part.startsWith('SecureMarkSig:')) {
          final base64Data = part.substring('SecureMarkSig:'.length);
          try {
            final fullPayload = base64Decode(base64Data);
            signature = _parseSignatureFromPayload(fullPayload, password);
          } catch (_) {}
        }
      }

      // 2. Look for Vector LSB in text objects
      // Note: Syncfusion doesn't easily expose individual character colors for existing text.
      // We mainly support extraction from PDFs we generated.
      // For now, if we found a file, we return it.
      
      document.dispose();
      return AnalysisResult(signature: signature, file: file);
    } catch (e) {
      debugPrint('Vector PDF analysis failed: $e');
      return const AnalysisResult();
    }
  }

  static String? _parseSignatureFromPayload(Uint8List fullPayload, String? password) {
    if (fullPayload.length >= 6) {
      final type = utf8.decode(fullPayload.sublist(0, 2));
      final payloadLength = (fullPayload[2] << 24) |
          (fullPayload[3] << 16) |
          (fullPayload[4] << 8) |
          (fullPayload[5]);

      if (fullPayload.length >= 6 + payloadLength + 2) {
        final payloadBytes = fullPayload.sublist(6, 6 + payloadLength);
        final extractedCrc =
            (fullPayload[6 + payloadLength] << 8) |
                fullPayload[6 + payloadLength + 1];

        return _extractTextFromPayload(
            payloadBytes, extractedCrc, type == 'SX', password);
      }
    }
    return null;
  }

  static Future<AnalysisResult> analyzeImageAsync(Uint8List bytes,
      {String? password}) async {
    return await Isolate.run(() => analyzeImage(bytes, password: password));
  }

  static AnalysisResult analyzeImage(Uint8List imageBytes, {String? password}) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return const AnalysisResult();

      String? signature;
      ExtractedFileResult? file;
      VerificationResult? verification;

      // Calculate current pixel hashes for dual-layer verification comparison
      final currentContentHash =
          _calculateForensicHash(image, excludeRedLSB: true);
      final currentSourceHash =
          _calculateForensicHash(image, excludeAllLSB: true);

      // Check each channel (B, G, R) for any of our steganography types
      for (final channel in ['b', 'g', 'r']) {
        final result = _checkChannel(image, channel, password);
        if (result.signature != null) {
          // Check if this is a verification deep-link
          if (result.signature!.startsWith('securemark://verify?v=')) {
            verification = _verifyDeepLink(
                result.signature!, currentContentHash, currentSourceHash);
          } else {
            signature = result.signature;
          }
        }
        if (result.file != null) {
          file = result.file;
        }
      }

      final robustSignature = _extractRobustSignature(image);

      return AnalysisResult(
        signature: signature,
        robustSignature: robustSignature,
        file: file,
        verification: verification,
      );
    } catch (e) {
      return const AnalysisResult();
    }
  }

  static AnalysisResult _checkChannel(
      img.Image image, String channel, String? password) {
    final int width = image.width;
    if (width * image.height < 64) return const AnalysisResult();

    final List<int> headerBytes = <int>[];
    var currentByte = 0;
    for (var i = 0; i < 16; i++) {
      final pixel = image.getPixel(i % width, i ~/ width);
      currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
      if ((i + 1) % 8 == 0) {
        headerBytes.add(currentByte);
        currentByte = 0;
      }
    }

    if (headerBytes[0] != 83) {
      return const AnalysisResult(); // 'S'
    }
    final type = headerBytes[1];
    debugPrint(
        '_checkChannel: channel=$channel, type=$type (${String.fromCharCode(type)})');
    if (type == 77 || type == 88) {
      return AnalysisResult(
          signature: _extractTextFromImage(image, type == 88, password,
              channel: channel));
    }
    if (type == 70 || type == 69) {
      debugPrint(
          '_checkChannel: Detected file in channel $channel, encrypted=${type == 69}');
      return AnalysisResult(
          file: _extractFileFromImage(image, type == 69, password,
              channel: channel));
    }

    debugPrint('_checkChannel: Unknown type $type in channel $channel');
    return const AnalysisResult();
  }

  static String? _extractTextFromImage(
      img.Image image, bool isEncrypted, String? password,
      {String channel = 'b'}) {
    try {
      final int width = image.width;
      final int totalPixels = width * image.height;
      final List<int> bytes = <int>[];
      var currentByte = 0;
      for (var i = 16; i < 48; i++) {
        final pixel = image.getPixel(i % width, i ~/ width);
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
      final int payloadBytesNeeded = payloadLength + 2;
      final int remainingPixels = totalPixels - 48;
      if (payloadBytesNeeded * 8 > remainingPixels) {
        return null;
      }
      final int stride =
          (remainingPixels ~/ (payloadBytesNeeded * 8)).clamp(1, 1000);
      currentByte = 0;
      bytes.clear();
      for (var i = 0; i < payloadBytesNeeded * 8; i++) {
        final pixelIdx = 48 + (i * stride);
        final pixel = image.getPixel(pixelIdx % width, pixelIdx ~/ width);
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
      
      return _extractTextFromPayload(payloadBytes, extractedCrc, isEncrypted, password);
    } catch (_) {
      return null;
    }
  }

  static String? _extractTextFromPayload(Uint8List payloadBytes, int extractedCrc, bool isEncrypted, String? password) {
    try {
      Uint8List data = payloadBytes;
      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          return '[ENCRYPTED] (Password required)';
        }
        final decrypted = _decryptBytes(payloadBytes, password);
        if (decrypted == null) {
          return '[ENCRYPTED] (Wrong password)';
        }
        data = decrypted;
      }
      if (_crc16(data) != extractedCrc) {
        return isEncrypted ? '[ENCRYPTED] (Wrong password)' : null;
      }
      return utf8.decode(data, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static ExtractedFileResult? _extractFileFromImage(
      img.Image image, bool isEncrypted, String? password,
      {String channel = 'g'}) {
    try {
      final int width = image.width;
      final int totalPixels = width * image.height;
      final List<int> bytes = <int>[];
      var currentByte = 0;
      for (var i = 16; i < 64; i++) {
        final pixel = image.getPixel(i % width, i ~/ width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }
      final int filenameLength = (bytes[0] << 8) | bytes[1];
      final int fileSize =
          (bytes[2] << 24) | (bytes[3] << 16) | (bytes[4] << 8) | bytes[5];
      debugPrint(
          'File extraction - filenameLength=$filenameLength, fileSize=$fileSize, encrypted=$isEncrypted');
      if (filenameLength <= 0 ||
          filenameLength > 255 ||
          fileSize <= 0 ||
          fileSize > 50 * 1024 * 1024) {
        debugPrint('File extraction failed - invalid metadata');
        return null;
      }
      final int totalDataBytes = filenameLength + fileSize + 2;
      final int remainingPixels = totalPixels - 64;
      if (totalDataBytes * 8 > remainingPixels) {
        return null;
      }
      final int stride =
          (remainingPixels ~/ (totalDataBytes * 8)).clamp(1, 1000);
      currentByte = 0;
      bytes.clear();
      for (var i = 0; i < totalDataBytes * 8; i++) {
        final pixelIdx = 64 + (i * stride);
        final pixel = image.getPixel(pixelIdx % width, pixelIdx ~/ width);
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
      debugPrint(
          'File extraction - filename="$filename", extractedCrc=$extractedCrc');
      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          debugPrint('File extraction - encrypted but no password provided');
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        final decrypted = _decryptBytes(fileBytes, password);
        if (decrypted == null) {
          debugPrint('File extraction - decryption failed');
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        fileBytes = decrypted;
        debugPrint(
            'File extraction - decrypted successfully, size=${fileBytes.length}');
      }
      final calculatedCrc = _crc16(fileBytes);
      debugPrint(
          'File extraction - calculatedCrc=$calculatedCrc, match=${calculatedCrc == extractedCrc}');
      if (calculatedCrc != extractedCrc) {
        debugPrint('File extraction - CRC mismatch');
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

  static Future<ExtractedFileResult?> extractFileAsync(Uint8List imageBytes,
      {String? password}) async {
    return await Isolate.run(() => extractFile(imageBytes, password: password));
  }

  static ExtractedFileResult? extractFile(Uint8List imageBytes,
      {String? password}) {
    final analysis = analyzeImage(imageBytes, password: password);
    return analysis.file;
  }

  static int _crc16(List<int> data) {
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

  static Uint8List _encryptBytes(Uint8List data, String password) {
    final keyBytes = sha256.convert(utf8.encode(password)).bytes;
    final key = enc.Key(Uint8List.fromList(keyBytes));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final result = BytesBuilder();
    result.add(iv.bytes);
    result.add(encrypted.bytes);
    return result.toBytes();
  }

  static Uint8List? _decryptBytes(Uint8List encryptedData, String password) {
    try {
      if (encryptedData.length < 16) {
        debugPrint(
            'Decryption failed: data too short (${encryptedData.length} bytes)');
        return null;
      }
      final iv = enc.IV(encryptedData.sublist(0, 16));
      final data = encryptedData.sublist(16);
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(data), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

  static img.Image _generateQrCodeImage(
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

  static String _buildQrMetadata(QrWatermarkConfig config) =>
      config.toQrString();

  static (int, int) _calculateQrPosition(
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

  static void _applyWatermarkField(
      img.Image image,
      String watermarkText,
      double transparency,
      double density,
      bool useRandomColor,
      int selectedColorValue,
      double fontSize,
      WatermarkFont font,
      Map<String, Uint8List>? preRenderedStamps,
      {double antiAiLevel = 0.0,
      QrWatermarkConfig? qrConfig,
      WatermarkType watermarkType = WatermarkType.text,
      Uint8List? watermarkImageBytes,
      ProgressCallback? onProgress}) {
    if (transparency < 100) {
      if (watermarkType == WatermarkType.text) {
        final placements = _buildPlacements(
            width: image.width,
            height: image.height,
            watermarkText: watermarkText,
            transparency: transparency,
            density: density,
            useRandomColor: useRandomColor,
            selectedColorValue: selectedColorValue,
            fontSize: fontSize.round(),
            font: font,
            onProgress: onProgress,
            progressStart: 0.0,
            progressEnd: 0.85);
        final stampCache = <String, img.Image>{};
        var stampIndex = 0;
        final totalStamps = placements.length;
        for (final placement in placements) {
          final jitterX =
              ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                  .round();
          final jitterY =
              ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                  .round();
          var stamp = stampCache.putIfAbsent(
              '${placement.angle.round()}-${placement.colorKey}',
              () => _buildWatermarkStamp(
                  watermarkText, placement, preRenderedStamps));
          if (antiAiLevel > 0) {
            stamp = stamp.clone();
            for (final pixel in stamp) {
              if (pixel.a > 0) {
                pixel.a = (pixel.a +
                        (antiAiLevel / 100.0) *
                            40 *
                            (_random.nextDouble() - 0.5))
                    .clamp(0, 255)
                    .toInt();
              }
            }
          }
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
        final logo = img.decodeImage(watermarkImageBytes);
        if (logo != null) {
          // Calculate scale based on fontSize (treating fontSize as target height)
          final resizedLogo = img.copyResize(logo, height: fontSize.round());

          // Ensure logo has an alpha channel (important for JPEGs)
          final scaledLogo = resizedLogo.numChannels == 4
              ? resizedLogo
              : resizedLogo.convert(numChannels: 4);

          // Apply transparency to the logo
          final alpha = _alphaFromTransparency(transparency);
          final alphaFactor = alpha / 255.0;
          for (final pixel in scaledLogo) {
            // Apply transparency while preserving original logo alpha channel
            pixel.a = (pixel.a * alphaFactor).round();
          }

          final placements = _buildPlacements(
              width: image.width,
              height: image.height,
              watermarkText: 'logo', // placeholder for count calculation
              transparency: transparency,
              density: density,
              useRandomColor: false,
              selectedColorValue: 0,
              fontSize: fontSize.round(),
              font: font,
              onProgress: onProgress,
              progressStart: 0.0,
              progressEnd: 0.85);

          var logoIndex = 0;
          final totalLogos = placements.length;
          for (final placement in placements) {
            final jitterX =
                ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                    .round();
            final jitterY =
                ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5))
                    .round();

            // Logos are no longer rotated per user request
            img.compositeImage(image, scaledLogo,
                dstX: placement.x + jitterX,
                dstY: placement.y + jitterY,
                blend: img.BlendMode.alpha);

            // Report progress every 5 logos to avoid excessive callbacks
            logoIndex++;
            if (logoIndex % 5 == 0 && onProgress != null) {
              final progress = 0.85 + (logoIndex / totalLogos) * 0.13;
              final message = antiAiLevel > 0
                  ? 'Applying logos with Anti-AI protection... ($logoIndex/$totalLogos)'
                  : 'Applying logo watermarks... ($logoIndex/$totalLogos)';
              onProgress(progress, message);
            }
          }
          // Report completion of logo application
          if (onProgress != null && totalLogos > 0) {
            final message = antiAiLevel > 0
                ? 'Logos applied with Anti-AI protection'
                : 'Logo watermarks applied';
            onProgress(0.98, message);
          }
        }
      }
    }
    if (qrConfig != null && qrConfig.visibleQr) {
      onProgress?.call(0.98, 'Generating QR code...');
      final qrSize = qrConfig.size.round();
      final qrImage =
          _generateQrCodeImage(data: _buildQrMetadata(qrConfig), size: qrSize);
      for (final pixel in qrImage) {
        pixel.a = (pixel.a * qrConfig.opacity).round();
      }
      final (x, y) = _calculateQrPosition(
          imageWidth: image.width,
          imageHeight: image.height,
          qrSize: qrSize,
          position: qrConfig.position);
      if (x >= 0 &&
          y >= 0 &&
          x + qrSize <= image.width &&
          y + qrSize <= image.height) {
        onProgress?.call(0.99, 'Embedding QR code...');
        img.compositeImage(image, qrImage,
            dstX: x, dstY: y, blend: img.BlendMode.alpha);
        onProgress?.call(1.0, 'QR code embedded');
      }
    }
  }

  static List<_Placement> _buildPlacements(
      {required int width,
      required int height,
      required String watermarkText,
      required double transparency,
      required double density,
      required bool useRandomColor,
      required int selectedColorValue,
      required int fontSize,
      required WatermarkFont font,
      ProgressCallback? onProgress,
      double progressStart = 0.0,
      double progressEnd = 1.0}) {
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

  static _Placement? _tryPlacementInCell(
      {required int width,
      required int height,
      required String watermarkText,
      required int cellColumn,
      required int cellRow,
      required double cellWidth,
      required double cellHeight,
      required List<_ResolvedColor> colorPool,
      required int fontSize,
      required WatermarkFont font}) {
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

  static _Placement? _tryPlacementAnywhere(
      {required int width,
      required int height,
      required String watermarkText,
      required List<_ResolvedColor> colorPool,
      required int fontSize,
      required WatermarkFont font}) {
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

  static int _watermarkCount(int w, int h, double d) =>
      max(8, ((w * h / 18000) * 2.69 * (d / 50).clamp(0.4, 2.0)).round());
  static int _alphaFromTransparency(double t) =>
      t >= 100 ? 0 : ((100 - t) / 100 * 255).round();

  static img.Image _resizeToTarget(img.Image image, int? targetSize) {
    if (targetSize == null || max(image.width, image.height) <= targetSize) {
      return image;
    }
    final s = targetSize / max(image.width, image.height);
    try {
      return img.copyResize(image,
          width: (image.width * s).round(),
          height: (image.height * s).round(),
          interpolation: img.Interpolation.average);
    } catch (e) {
      throw WatermarkError(
          type: WatermarkErrorType.memoryLimitExceeded,
          message: 'Not enough memory to resize image',
          originalError: e);
    }
  }

  static Uint8List _encodePngForSharing(img.Image image) =>
      Uint8List.fromList(img.encodePng(image, level: 2));

  static Uint8List _encodeImageInOriginalFormat(
      img.Image image, String ext, int q, bool stegan) {
    if (stegan || ext.toLowerCase() == '.png' || ext.toLowerCase() == '.webp') {
      return Uint8List.fromList(img.encodePng(image, level: 2));
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: q));
  }

  static double _randomAngle() =>
      _random.nextInt((360 / _angleStepDegrees).round()) * _angleStepDegrees;

  static List<_ResolvedColor> _buildColorPool(bool rnd, int val, int a) => rnd
      ? List.generate(_randomColorPoolSize,
          (i) => _ResolvedColor(key: i, color: _randomWatermarkColor(a)))
      : [
          _ResolvedColor(
              key: (a << 24) | (val & 0xFFFFFF),
              color: _resolveWatermarkColor(false, val, a))
        ];

  static _ResolvedColor _pickColor(List<_ResolvedColor> pool) =>
      pool[_random.nextInt(pool.length)];

  static img.Color _randomWatermarkColor(int a) {
    final h = _random.nextDouble() * 360;
    const s = 0.8;
    const v = 0.95;
    const c = v * s;
    final x = c * (1 - (((h / 60) % 2) - 1).abs());
    const m = v - c;
    double r, g, b;
    if (h < 60) {
      r = c;
      g = x;
      b = 0;
    } else if (h < 120) {
      r = x;
      g = c;
      b = 0;
    } else if (h < 180) {
      r = 0;
      g = c;
      b = x;
    } else if (h < 240) {
      r = 0;
      g = x;
      b = c;
    } else if (h < 300) {
      r = x;
      g = 0;
      b = c;
    } else {
      r = c;
      g = 0;
      b = x;
    }
    return img.ColorRgba8(((r + m) * 255).round(), ((g + m) * 255).round(),
        ((b + m) * 255).round(), a);
  }

  static img.Color _resolveWatermarkColor(bool rnd, int val, int a) => rnd
      ? _randomWatermarkColor(a)
      : img.ColorRgba8((val >> 16) & 0xFF, (val >> 8) & 0xFF, val & 0xFF, a);

  // --- Deep-Linking Verification Logic ---

  /// A static secret key for signing verification tokens.
  /// In a production app, this would be per-user and stored in a secure enclave.
  static const String _verificationSecret = 'sm-p-v-key-32-chars-long-secret!';

  static String _generateVerificationLink(
      String author, String contentHash, String sourceHash) {
    final payload = jsonEncode({
      'a': author,
      't': DateTime.now().toIso8601String(),
      'h1': contentHash,
      'h2': sourceHash,
    });

    final key = enc.Key.fromUtf8(_verificationSecret);
    final iv =
        enc.IV.fromUtf8('sm-iv-16-chars!!'); // Use a fixed IV for the seal
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encrypt(payload, iv: iv);
    return 'securemark://verify?v=${encrypted.base64}';
  }

  static VerificationResult? _verifyDeepLink(
      String link, String currentContentHash, String currentSourceHash) {
    try {
      if (!link.startsWith('securemark://verify?v=')) return null;
      final encryptedBase64 = link.split('securemark://verify?v=').last;

      final key = enc.Key.fromUtf8(_verificationSecret);
      final iv = enc.IV.fromUtf8('sm-iv-16-chars!!'); // Match the fixed IV
      final encrypter = enc.Encrypter(enc.AES(key));

      final decrypted =
          encrypter.decrypt(enc.Encrypted.fromBase64(encryptedBase64), iv: iv);
      final data = jsonDecode(decrypted);

      final author = data['a'] as String;
      final timestamp = DateTime.parse(data['t'] as String);
      final originalContentHash = data['h1'] as String;
      final originalSourceHash = data['h2'] as String;

      final isContentAuthentic = originalContentHash == currentContentHash;
      final isSourceAuthentic = originalSourceHash == currentSourceHash;

      String messageKey;
      if (isContentAuthentic) {
        messageKey = 'verifFullIntegrity';
      } else if (isSourceAuthentic) {
        messageKey = 'verifPartialIntegrity';
      } else {
        messageKey = 'verifTamperingDetected';
      }

      return VerificationResult(
        isContentAuthentic: isContentAuthentic,
        isSourceAuthentic: isSourceAuthentic,
        author: author,
        timestamp: timestamp,
        messageKey: messageKey,
      );
    } catch (e) {
      debugPrint('Deep-link verification error: $e');
      return null;
    }
  }

  static Future<ProcessResult> _processPdfRasterFallback({
    required Uint8List inputBytes,
    required File file,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    required WatermarkFont font,
    required int jpegQuality,
    bool includeTimestamp = false,
    String filePrefix = 'securemark-',
    double antiAiLevel = 0.0,
    bool useSteganography = false,
    bool useRobustSteganography = false,
    bool useAiCloaking = false,
    WatermarkType watermarkType = WatermarkType.text,
    Uint8List? watermarkImageBytes,
    String? steganographyPassword,
    String? steganographyText,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final doc = pw.Document();
      Uint8List? preview;
      var hasPages = false;
      var pageCount = 0;
      var processed = 0;
      Uint8List? firstPageOriginal;

      final steganographySignature =
          (steganographyText != null && steganographyText.isNotEmpty)
              ? steganographyText
              : watermarkText;

      await for (final page in Printing.raster(inputBytes, dpi: 150)) {
        if (cancellationToken?.isCancelled == true) {
          throw const WatermarkError(
              type: WatermarkErrorType.operationCancelled,
              message: 'Operation cancelled');
        }
        hasPages = true;
        pageCount++;
        final png = await page.toPng();
        firstPageOriginal ??= png;
        final decoded = img.decodeImage(png);
        var watermarked = img.Image.from(decoded!);

        if (useAiCloaking) {
          watermarked = _applyAiCloaking(watermarked);
        }

        Map<String, Uint8List>? stamps;
        if (watermarkType == WatermarkType.text && !font.isBitmap) {
          final bytes = await _renderTextWithFlutterCanvas(
              text: watermarkText,
              font: font,
              fontSize: fontSize.round(),
              color: const ui.Color.fromARGB(255, 255, 255, 255));
          stamps = {'${font.fontFamily}-${fontSize.round()}': bytes};
        }
        // Calculate progress range for this page within overall PDF processing
        final pageProgressStart = 0.3 + (processed / (pageCount + 1)) * 0.6;
        final pageProgressEnd = 0.3 + ((processed + 1) / (pageCount + 1)) * 0.6;
        final pageProgressRange = pageProgressEnd - pageProgressStart;

        _applyWatermarkField(watermarked, watermarkText, transparency, density,
            useRandomColor, selectedColorValue, fontSize, font, stamps,
            antiAiLevel: antiAiLevel,
            qrConfig: qrConfig,
            watermarkType: watermarkType,
            watermarkImageBytes: watermarkImageBytes,
            onProgress: (progress, message) {
          // Map watermark progress (0.0-1.0) to this page's range
          onProgress?.call(pageProgressStart + (progress * pageProgressRange),
              'Page ${processed + 1}: $message');
        });
        if (useRobustSteganography) {
          watermarked =
              _embedRobustSignature(watermarked, steganographySignature);
        }
        if (useSteganography) {
          if (hiddenFileName != null && hiddenFileBytes != null) {
            watermarked = _embedFileIntoImage(
                watermarked, hiddenFileName, hiddenFileBytes,
                password: steganographyPassword, channel: 'g');
          }
          // Always embed watermark text as LSB if steganography is enabled (Blue channel)
          watermarked = _embedLSB(watermarked, steganographySignature,
              password: steganographyPassword, channel: 'b');
        }
        final encoded = _encodePngForSharing(watermarked);
        preview ??= encoded;
        doc.addPage(pw.Page(
            pageFormat:
                PdfPageFormat(page.width.toDouble(), page.height.toDouble()),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.SizedBox.expand(
                child:
                    pw.Image(pw.MemoryImage(encoded), fit: pw.BoxFit.fill))));
        processed++;
      }
      if (!hasPages) {
        throw WatermarkError(
            type: WatermarkErrorType.invalidPdfData,
            message: 'No readable pages',
            filePath: file.path);
      }
      final out = await doc.save();
      final path = _outputPath(file.path, '.pdf', includeTimestamp, filePrefix);
      bool verified = false;
      bool robustVerified = false;
      if ((useSteganography ||
              useRobustSteganography ||
              hiddenFileName != null) &&
          preview != null) {
        final analysis = analyzeImage(preview, password: steganographyPassword);

        if (useSteganography || hiddenFileName != null) {
          bool allVerified = true;
          if (hiddenFileName != null) {
            allVerified &= (analysis.file != null &&
                analysis.file!.fileName == hiddenFileName);
          }
          if (useSteganography) {
            allVerified &=
                (analysis.signature?.startsWith(steganographySignature) ??
                    false);
          }
          verified = allVerified;
        }

        if (useRobustSteganography) {
          robustVerified =
              analysis.robustSignature?.startsWith(steganographySignature) ??
                  false;
        }
      }

      // Generate heatmap for the first page
      Uint8List? heatmapBytes;
      if (firstPageOriginal != null && preview != null) {
        try {
          final originalImg = img.decodeImage(firstPageOriginal);
          final processedImg = img.decodeImage(preview);
          if (originalImg != null && processedImg != null) {
            final heatmap = _generateHeatmapImage(originalImg, processedImg);
            if (heatmap != null) {
              heatmapBytes =
                  Uint8List.fromList(img.encodeJpg(heatmap, quality: 85));
            }
          }
        } catch (e) {
          debugPrint('Failed to generate PDF raster heatmap: $e');
        }
      }

      return ProcessResult(
          outputPath: path,
          outputBytes: out,
          previewBytes: preview,
          originalBytes: firstPageOriginal,
          heatmapBytes: heatmapBytes,
          steganographyVerified: verified,
          robustVerified: robustVerified,
          isPdf: true);
    } catch (e) {
      throw WatermarkError(
          type: WatermarkErrorType.invalidPdfData,
          message: 'Failed PDF raster',
          filePath: file.path,
          originalError: e);
    }
  }

  static String _outputPath(String path, String ext,
      [bool ts = false, String pref = 'securemark-']) {
    String s = '';
    if (ts) {
      final n = DateTime.now();
      s = '-${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}-${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
    }
    return p.join(
        p.dirname(path), '$pref${p.basenameWithoutExtension(path)}$s$ext');
  }

  static String _resolvedWatermarkText(String t) {
    final n = DateTime.now();
    final d =
        '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final s =
        '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
    return t.trim().isEmpty ? '$d $s' : '${t.trim()} $d $s';
  }

  /// Applies adversarial AI cloaking with multi-band frequency attacks.
  /// Disrupts style transfer, CNN feature extraction, and OCR while remaining imperceptible.
  static img.Image _applyAiCloaking(img.Image image) {
    final width = image.width;
    final height = image.height;
    final numBlocksX = width ~/ 8;
    final numBlocksY = height ~/ 8;

    final output = img.Image.from(image);

    // Pre-compute edge map and text regions for adaptive processing
    final edgeMap = _computeEdgeMap(image, numBlocksX, numBlocksY);
    final textMap = _detectTextRegions(image, numBlocksX, numBlocksY);

    for (var by = 0; by < numBlocksY; by++) {
      for (var bx = 0; bx < numBlocksX; bx++) {
        final blockY = List<double>.filled(64, 0.0);
        final blockCb = List<double>.filled(64, 0.0);
        final blockCr = List<double>.filled(64, 0.0);

        // 1. Extract YCbCr for all channels
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final p = image.getPixel(bx * 8 + x, by * 8 + y);
            blockY[y * 8 + x] = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
            blockCb[y * 8 + x] = -0.1687 * p.r - 0.3313 * p.g + 0.5 * p.b + 128;
            blockCr[y * 8 + x] = 0.5 * p.r - 0.4187 * p.g - 0.0813 * p.b + 128;
          }
        }

        // 2. DCT transform all channels
        final dctY = _dct8x8(blockY);
        final dctCb = _dct8x8(blockCb);
        final dctCr = _dct8x8(blockCr);

        // 3. Texture-aware adaptive strength
        final variance = _calculateVariance(blockY);
        final isTextured = variance > 400;
        final isEdge = edgeMap[by * numBlocksX + bx] > 0.3;
        final isText = textMap[by * numBlocksX + bx] > 0.4;

        // Base strength multipliers
        final baseStrength = isTextured ? 1.5 : 1.0;
        final edgeMultiplier =
            isEdge ? 0.7 : 1.0; // Reduce on edges for invisibility
        final textMultiplier = isText ? 1.3 : 1.0; // Boost in text regions

        // 4. Multi-band adversarial attacks
        for (var i = 1; i < 64; i++) {
          final u = i % 8;
          final v = i ~/ 8;
          final freq = u + v; // Approximate frequency

          // Deterministic but pseudo-random noise
          final seed = (bx * 73 + by * 137 + i * 211) % 1000;
          final noiseBase = (sin(seed * 0.01) * 2.0 - 1.0);

          double attackStrength = 0.0;

          // Low-mid frequencies (8-20): Gram matrix / style transfer attack
          if (freq >= 8 && freq < 20) {
            attackStrength = 18.0 * baseStrength * edgeMultiplier;
            dctY[i] += noiseBase * attackStrength;
            // Anti-correlate Cb/Cr to disrupt color statistics
            dctCb[i] += noiseBase * attackStrength * -0.5;
            dctCr[i] += noiseBase * attackStrength * 0.5;
          }

          // Mid frequencies (20-40): CNN feature extraction attack
          if (freq >= 20 && freq < 40) {
            attackStrength = 25.0 * baseStrength * textMultiplier;
            dctY[i] += noiseBase * attackStrength;
            dctCb[i] += noiseBase * attackStrength * 0.3;
            dctCr[i] += noiseBase * attackStrength * -0.3;
          }

          // High frequencies (40-64): Fine texture disruption
          if (freq >= 40) {
            attackStrength = 15.0 * baseStrength;
            dctY[i] += noiseBase * attackStrength;
          }

          // OCR-specific attacks in text regions
          if (isText) {
            // Target horizontal baselines (rows 2-4)
            if (v >= 2 && v <= 4 && u >= 3 && u <= 6) {
              dctY[i] += noiseBase * 12.0;
            }
            // Target vertical character strokes (columns 3-5)
            if (u >= 3 && u <= 5 && v >= 1 && v <= 6) {
              dctY[i] += noiseBase * 10.0;
            }
            // Disrupt connected components (corners)
            if ((u <= 2 && v <= 2) || (u >= 6 && v >= 6)) {
              dctY[i] += noiseBase * 8.0;
            }
          }
        }

        // 5. IDCT back to spatial domain
        final newY = _idct8x8(dctY);
        final newCb = _idct8x8(dctCb);
        final newCr = _idct8x8(dctCr);

        // 6. Reconstruct RGB with perceptual masking
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final yVal = newY[y * 8 + x];
            final cbVal = newCb[y * 8 + x] - 128;
            final crVal = newCr[y * 8 + x] - 128;

            final r = (yVal + 1.402 * crVal).clamp(0, 255).toInt();
            final g = (yVal - 0.344136 * cbVal - 0.714136 * crVal)
                .clamp(0, 255)
                .toInt();
            final b = (yVal + 1.772 * cbVal).clamp(0, 255).toInt();

            output.setPixel(bx * 8 + x, by * 8 + y, img.ColorRgb8(r, g, b));
          }
        }
      }
    }
    return output;
  }

  /// Computes edge strength map for adaptive processing
  static List<double> _computeEdgeMap(
      img.Image image, int numBlocksX, int numBlocksY) {
    final edgeMap = List<double>.filled(numBlocksX * numBlocksY, 0.0);

    for (var by = 0; by < numBlocksY; by++) {
      for (var bx = 0; bx < numBlocksX; bx++) {
        double edgeStrength = 0.0;
        int count = 0;

        // Sample edge strength within this block
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final px = bx * 8 + x;
            final py = by * 8 + y;

            if (px >= image.width - 1 || py >= image.height - 1) continue;

            final p = image.getPixel(px, py);
            final gray = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;

            // Sobel-like gradient
            final pRight = image.getPixel(px + 1, py);
            final pDown = image.getPixel(px, py + 1);

            final grayRight =
                0.299 * pRight.r + 0.587 * pRight.g + 0.114 * pRight.b;
            final grayDown =
                0.299 * pDown.r + 0.587 * pDown.g + 0.114 * pDown.b;

            final gx = (gray - grayRight).abs();
            final gy = (gray - grayDown).abs();

            edgeStrength += (gx + gy) / 2;
            count++;
          }
        }

        edgeMap[by * numBlocksX + bx] =
            count > 0 ? (edgeStrength / count) / 255.0 : 0.0;
      }
    }

    return edgeMap;
  }

  /// Calculates variance of a block for texture detection
  static double _calculateVariance(List<double> blockY) {
    if (blockY.isEmpty) return 0.0;
    final mean = blockY.reduce((a, b) => a + b) / blockY.length;
    double variance = 0.0;
    for (final val in blockY) {
      final diff = val - mean;
      variance += diff * diff;
    }
    return variance / blockY.length;
  }

  /// Detects text regions using edge patterns and variance
  static List<double> _detectTextRegions(
      img.Image image, int numBlocksX, int numBlocksY) {
    final textMap = List<double>.filled(numBlocksX * numBlocksY, 0.0);

    for (var by = 0; by < numBlocksY; by++) {
      for (var bx = 0; bx < numBlocksX; bx++) {
        double variance = 0.0;
        double horizontalEdges = 0.0;
        double verticalEdges = 0.0;
        final values = <double>[];

        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final px = bx * 8 + x;
            final py = by * 8 + y;

            if (px >= image.width || py >= image.height) continue;

            final pixel = image.getPixel(px, py);
            final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
            values.add(gray);

            // Edge detection
            if (px < image.width - 1) {
              final pRight = image.getPixel(px + 1, py);
              final grayRight =
                  0.299 * pRight.r + 0.587 * pRight.g + 0.114 * pRight.b;
              verticalEdges += (gray - grayRight).abs();
            }

            if (py < image.height - 1) {
              final pDown = image.getPixel(px, py + 1);
              final grayDown =
                  0.299 * pDown.r + 0.587 * pDown.g + 0.114 * pDown.b;
              horizontalEdges += (gray - grayDown).abs();
            }
          }
        }

        // Calculate variance
        if (values.isNotEmpty) {
          final mean = values.reduce((a, b) => a + b) / values.length;
          for (final val in values) {
            final diff = val - mean;
            variance += diff * diff;
          }
          variance /= values.length;
        }

        // Text characteristics:
        // 1. Moderate variance (200-800)
        // 2. Strong horizontal edges (text lines/baselines)
        // 3. Strong vertical edges (character strokes)
        // 4. Vertical edges stronger than horizontal

        final normalizedVariance =
            (variance > 200 && variance < 800) ? 1.0 : 0.0;
        final normalizedHorizontal =
            (horizontalEdges / (8 * 8 * 255.0)).clamp(0.0, 1.0);
        final normalizedVertical =
            (verticalEdges / (8 * 8 * 255.0)).clamp(0.0, 1.0);

        final textScore = normalizedVariance * 0.3 +
            normalizedHorizontal * 0.3 +
            normalizedVertical * 0.4;

        textMap[by * numBlocksX + bx] = textScore.clamp(0.0, 1.0);
      }
    }

    return textMap;
  }

  // --- Robust DCT Watermarking (Frequency Domain) ---

  /// Embeds a signature robustly using DCT on 8x8 blocks of the Y (Luminance) channel.
  static img.Image _embedRobustSignature(img.Image image, String signature) {
    if (signature.isEmpty) return image;

    // Convert signature to bits
    final bits = _getRobustSignatureBits(signature);
    if (bits.isEmpty) return image;

    final width = image.width;
    final height = image.height;

    // We need 8x8 blocks. Calculate how many blocks we have.
    final numBlocksX = width ~/ 8;
    final numBlocksY = height ~/ 8;

    if (numBlocksX * numBlocksY < bits.length) {
      // Image too small for this signature, but we'll embed what we can
    }

    // Embed each bit into a block
    int bitIdx = 0;
    for (var by = 0; by < numBlocksY && bitIdx < bits.length; by++) {
      for (var bx = 0; bx < numBlocksX && bitIdx < bits.length; bx++) {
        // 1. Extract 8x8 block Y channel
        final blockY = List<double>.filled(64, 0.0);
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final pixel = image.getPixel(bx * 8 + x, by * 8 + y);
            // Y = 0.299R + 0.587G + 0.114B
            blockY[y * 8 + x] =
                0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          }
        }

        // 2. Perform DCT
        final dctBlock = _dct8x8(blockY);

        // 3. Embed bit into mid-frequency coefficient (e.g., [4, 4])
        const coeffIdx = 4 * 8 + 4;
        const strength = 20.0; // Robustness factor

        if (bits[bitIdx]) {
          if (dctBlock[coeffIdx] < strength) {
            dctBlock[coeffIdx] = strength;
          } else {
            dctBlock[coeffIdx] += strength;
          }
        } else {
          if (dctBlock[coeffIdx] > -strength) {
            dctBlock[coeffIdx] = -strength;
          } else {
            dctBlock[coeffIdx] -= strength;
          }
        }

        // 4. Perform Inverse DCT
        final idctBlock = _idct8x8(dctBlock);

        // 5. Update image
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final pixel = image.getPixel(bx * 8 + x, by * 8 + y);
            final oldY = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
            final diff = idctBlock[y * 8 + x] - oldY;

            pixel.r = (pixel.r + diff).clamp(0, 255).toInt();
            pixel.g = (pixel.g + diff).clamp(0, 255).toInt();
            pixel.b = (pixel.b + diff).clamp(0, 255).toInt();
          }
        }

        bitIdx++;
      }
    }

    return image;
  }

  /// Extracts a signature robustly from DCT coefficients.
  static String? _extractRobustSignature(img.Image image) {
    final width = image.width;
    final height = image.height;
    final numBlocksX = width ~/ 8;
    final numBlocksY = height ~/ 8;

    final bits = <bool>[];
    for (var by = 0; by < numBlocksY; by++) {
      for (var bx = 0; bx < numBlocksX; bx++) {
        final blockY = List<double>.filled(64, 0.0);
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            final pixel = image.getPixel(bx * 8 + x, by * 8 + y);
            blockY[y * 8 + x] =
                0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
          }
        }

        final dctBlock = _dct8x8(blockY);
        const coeffIdx = 4 * 8 + 4;
        bits.add(dctBlock[coeffIdx] > 0);
        if (bits.length > 1024 * 8) {
          break;
        }
      }
      if (bits.length > 1024 * 8) {
        break;
      }
    }

    if (bits.length < 16) return null;
    final bytes = <int>[];
    for (var i = 0; i < bits.length ~/ 8; i++) {
      var byte = 0;
      for (var b = 0; b < 8; b++) {
        if (bits[i * 8 + b]) byte |= (1 << (7 - b));
      }
      bytes.add(byte);
    }

    if (bytes[0] != 83 || bytes[1] != 82) return null; // 'S', 'R'

    final length = (bytes[2] << 8) | bytes[3];
    if (length <= 0 || length > 1024) return null;
    if (bytes.length < 4 + length) return null;

    try {
      return utf8.decode(bytes.sublist(4, 4 + length), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  static List<bool> _getRobustSignatureBits(String signature) {
    final payload = <int>[];
    payload.add(83); // 'S'
    payload.add(82); // 'R'
    final sigBytes = utf8.encode(signature);
    payload.add((sigBytes.length >> 8) & 0xFF);
    payload.add(sigBytes.length & 0xFF);
    payload.addAll(sigBytes);

    final bits = <bool>[];
    for (final byte in payload) {
      for (var i = 7; i >= 0; i--) {
        bits.add(((byte >> i) & 1) == 1);
      }
    }
    return bits;
  }

  static List<double> _dct8x8(List<double> input) {
    final output = List<double>.filled(64, 0.0);
    for (var v = 0; v < 8; v++) {
      for (var u = 0; u < 8; u++) {
        var sum = 0.0;
        for (var y = 0; y < 8; y++) {
          for (var x = 0; x < 8; x++) {
            sum += input[y * 8 + x] *
                cos((2 * x + 1) * u * pi / 16.0) *
                cos((2 * y + 1) * v * pi / 16.0);
          }
        }
        final cu = (u == 0) ? (1.0 / sqrt(2.0)) : 1.0;
        final cv = (v == 0) ? (1.0 / sqrt(2.0)) : 1.0;
        output[v * 8 + u] = 0.25 * cu * cv * sum;
      }
    }
    return output;
  }

  static List<double> _idct8x8(List<double> input) {
    final output = List<double>.filled(64, 0.0);
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        var sum = 0.0;
        for (var v = 0; v < 8; v++) {
          for (var u = 0; u < 8; u++) {
            final cu = (u == 0) ? (1.0 / sqrt(2.0)) : 1.0;
            final cv = (v == 0) ? (1.0 / sqrt(2.0)) : 1.0;
            sum += cu *
                cv *
                input[v * 8 + u] *
                cos((2 * x + 1) * u * pi / 16.0) *
                cos((2 * y + 1) * v * pi / 16.0);
          }
        }
        output[y * 8 + x] = 0.25 * sum;
      }
    }
    return output;
  }

  static List<int> _bytesToBits(Uint8List bytes) {
    final bits = <int>[];
    for (final byte in bytes) {
      for (var i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }
    return bits;
  }

  static List<int> _textToBits(String text) {
    return _bytesToBits(Uint8List.fromList(utf8.encode(text)));
  }

  static Uint8List _encryptFileForSteganography({
    required String fileName,
    required Uint8List fileBytes,
    String? password,
  }) {
    final filenameBytes = utf8.encode(fileName);
    final payload = BytesBuilder();

    // Format: [Filename Length (2 bytes)] [Filename] [File Size (4 bytes)] [File Data] [CRC (2 bytes)]
    payload.add([
      (filenameBytes.length >> 8) & 0xFF,
      filenameBytes.length & 0xFF,
    ]);
    payload.add(filenameBytes);

    final fileSize = fileBytes.length;
    payload.add([
      (fileSize >> 24) & 0xFF,
      (fileSize >> 16) & 0xFF,
      (fileSize >> 8) & 0xFF,
      fileSize & 0xFF,
    ]);
    payload.add(fileBytes);

    final crc = _crc16(fileBytes);
    payload.add([(crc >> 8) & 0xFF, crc & 0xFF]);

    final rawPayload = payload.toBytes();

    if (password != null && password.isNotEmpty) {
      return _encryptBytes(rawPayload, password);
    }
    return rawPayload;
  }

  static ExtractedFileResult? _decryptFileFromSteganography(
      Uint8List encryptedData, String? password) {
    try {
      Uint8List data = encryptedData;
      if (password != null && password.isNotEmpty) {
        final decrypted = _decryptBytes(encryptedData, password);
        if (decrypted == null) return null;
        data = decrypted;
      }

      final filenameLength = (data[0] << 8) | data[1];
      if (filenameLength <= 0 || filenameLength > 255) return null;

      final fileName = utf8.decode(data.sublist(2, 2 + filenameLength));
      final fileSize = (data[2 + filenameLength] << 24) |
          (data[3 + filenameLength] << 16) |
          (data[4 + filenameLength] << 8) |
          (data[5 + filenameLength]);

      final fileBytes =
          data.sublist(6 + filenameLength, 6 + filenameLength + fileSize);
      final extractedCrc = (data[data.length - 2] << 8) | data[data.length - 1];

      if (_crc16(fileBytes) != extractedCrc) return null;

      return ExtractedFileResult(
        fileName: fileName,
        fileBytes: fileBytes,
        isEncrypted: password != null && password.isNotEmpty,
      );
    } catch (e) {
      debugPrint('Error decrypting hidden file: $e');
      return null;
    }
  }
}
