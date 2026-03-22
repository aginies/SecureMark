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
    this.steganographyVerified = false,
    this.robustVerified = false,
  });

  final String outputPath;
  final Uint8List outputBytes;
  final Uint8List? previewBytes;
  final Uint8List? originalBytes;
  final bool steganographyVerified;
  final bool robustVerified;
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

class AnalysisResult {
  const AnalysisResult({
    this.signature,
    this.robustSignature,
    this.file,
    this.qrData,
  });

  final String? signature;
  final String? robustSignature;
  final ExtractedFileResult? file;
  final String? qrData;
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
  });

  final bool isValid;
  final WatermarkError? error;
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
  /// Cache for processed results to avoid reprocessing identical requests
  static final Map<String, ProcessResult> _resultCache =
      <String, ProcessResult>{};

  /// Maximum cache size to prevent memory issues
  static const int _maxCacheSize = 10;

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
    String? steganographyPassword,
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

    onProgress?.call(0.0, 'Validating file...');

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
      steganographyPassword,
      hiddenFileName,
      hiddenFileBytes,
      qrConfig,
    );

    if (_resultCache.containsKey(cacheKey)) {
      onProgress?.call(1.0, 'Retrieved from cache');
      return _resultCache[cacheKey]!;
    }

    try {
      onProgress?.call(0.1, 'Processing file...');

      final extension = p.extension(file.path).toLowerCase();
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
          steganographyPassword: steganographyPassword,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: onProgress,
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
          steganographyPassword: steganographyPassword,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: onProgress,
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

      onProgress?.call(1.0, 'Processing complete');
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

      // Check file extension
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
      if (!supportedExtensions.contains(extension)) {
        return _ValidationResult(
          isValid: false,
          error: WatermarkError(
            type: WatermarkErrorType.unsupportedFileType,
            message: 'Unsupported file extension: $extension',
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

      return const _ValidationResult(isValid: true);
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
    String? steganographyPassword,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
  ) {
    final hiddenFileHash =
        hiddenFileBytes != null ? hiddenFileBytes.length.toString() : 'none';
    final qrHash = qrConfig != null
        ? '${qrConfig.visibleQr}-${qrConfig.invisibleQr}-${qrConfig.author}-${qrConfig.url}-${qrConfig.position}-${qrConfig.size}'
        : 'none';
    return '$filePath-$transparency-$density-$watermarkText-$useRandomColor-$selectedColorValue-$fontSize-${font.fontFamily}-$jpegQuality-$targetSize-$includeTimestamp-$preserveMetadata-$rasterizePdf-$filePrefix-$antiAiLevel-$useSteganography-$useRobustSteganography-$steganographyPassword-$hiddenFileName-$hiddenFileHash-$qrHash';
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
    String? steganographyPassword,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    try {
      onProgress?.call(0.2, 'Reading image file...');

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
      if (!font.isBitmap) {
        onProgress?.call(0.3, 'Rendering font...');
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
          // Continue without pre-rendered stamps, will use bitmap fallback
        }
      }

      onProgress?.call(0.4, 'Processing image...');

      final outputBytes = await Isolate.run(
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
          filePath: file.path,
          originalExtension: extension,
          preserveMetadata: preserveMetadata,
          antiAiLevel: antiAiLevel,
          useSteganography: useSteganography,
          useRobustSteganography: useRobustSteganography,
          steganographyPassword: steganographyPassword,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          preRenderedStamps: preRenderedStamps,
        ),
      );

      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Operation cancelled during image processing',
        );
      }

      onProgress?.call(0.9, 'Finalizing image...');

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
          hiddenFileName != null ||
          (qrConfig?.invisibleQr == true)) {
        onProgress?.call(0.95, 'Verifying steganography...');

        // Use the new combined analyzer for verification
        final analysis =
            analyzeImage(outputBytes, password: steganographyPassword);

        if (useSteganography ||
            hiddenFileName != null ||
            (qrConfig?.invisibleQr == true)) {
          bool allVerified = true;
          if (hiddenFileName != null) {
            allVerified &= (analysis.file != null &&
                analysis.file!.fileName == hiddenFileName);
          }
          if (qrConfig?.invisibleQr == true) {
            allVerified &=
                (analysis.qrData != null && analysis.qrData!.isNotEmpty);
          }
          if (useSteganography) {
            allVerified &= (analysis.signature == watermarkText);
          }
          verified = allVerified;
        }

        if (useRobustSteganography) {
          robustVerified = analysis.robustSignature == watermarkText;
        }

        if (verified || robustVerified) {
          onProgress?.call(0.98, 'Steganography verified');
        } else {
          onProgress?.call(0.98, 'Steganography verification failed');
        }
      }

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: outputBytes,
        originalBytes: inputBytes, // Store original bytes for A/B comparison
        steganographyVerified: verified,
        robustVerified: robustVerified,
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
    String? steganographyPassword,
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
          steganographyPassword: steganographyPassword,
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

      // Move heavy PDF processing to Isolate
      Uint8List outputBytes;
      try {
        outputBytes = await Isolate.run(
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
          ),
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
          steganographyPassword: steganographyPassword,
          hiddenFileName: hiddenFileName,
          hiddenFileBytes: hiddenFileBytes,
          qrConfig: qrConfig,
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
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

      // Generate a preview of the first page using the existing Printing logic
      final preview =
          await Printing.raster(outputBytes, pages: [0], dpi: 72).first;
      final previewBytes = await preview.toPng();

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: previewBytes,
        originalBytes: inputBytes, // Store original bytes for A/B comparison
        steganographyVerified: false,
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
  }) {
    sync.PdfDocument document;
    try {
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
    final alpha = (100 - transparency).clamp(10, 90) / 100;
    final pdfFont =
        sync.PdfStandardFont(sync.PdfFontFamily.helvetica, fontSize);

    for (var i = 0; i < pageCount; i++) {
      final page = document.pages[i];
      final pageSize = page.size;
      final graphics = page.graphics;

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
          final jitterAngle =
              (antiAiLevel / 100.0) * 15.0 * (_random.nextDouble() - 0.5);

          final x = (col * cellWidth) +
              (_random.nextDouble() * (cellWidth * 0.3)) +
              jitterX;
          final y = (row * cellHeight) +
              (_random.nextDouble() * (cellHeight * 0.3)) +
              jitterY;
          final angle = _randomAngle() + jitterAngle;

          graphics.translateTransform(x, y);
          graphics.rotateTransform(angle);
          graphics.setTransparency(alpha);
          graphics.drawString(watermarkText, pdfFont, brush: brush);
          graphics.restore();
        }
      }
    }

    final List<int> bytes = document.saveSync();
    document.dispose();
    return Uint8List.fromList(bytes);
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

  static Uint8List _renderWatermarkedImageBytesWithValidation({
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
    String? steganographyPassword,
    String? hiddenFileName,
    Uint8List? hiddenFileBytes,
    QrWatermarkConfig? qrConfig,
    Map<String, Uint8List>? preRenderedStamps,
  }) {
    try {
      final decoded = img.decodeImage(inputBytes);
      if (decoded == null) {
        throw WatermarkError(
          type: WatermarkErrorType.invalidImageData,
          message: 'Unable to decode image data',
          filePath: filePath,
        );
      }

      final resized = _resizeToTarget(decoded, targetSize);
      var outputImage = img.Image.from(resized);

      if (preserveMetadata && !decoded.exif.isEmpty) {
        outputImage.exif = decoded.exif.clone();
      }

      outputImage.textData ??= {};
      outputImage.textData!['Description'] =
          'SecureMark (https://github.com/aginies/SecureMark)';
      outputImage.textData!['Software'] = 'SecureMark';

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
      );

      if (useRobustSteganography) {
        outputImage = _embedRobustSignature(outputImage, watermarkText);
      }

      if (useSteganography) {
        if (hiddenFileName != null && hiddenFileBytes != null) {
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
        outputImage = _embedLSB(
          outputImage,
          watermarkText,
          password: steganographyPassword,
          channel: 'b', // Use Blue channel for signature
        );
      }

      var forcePng = useSteganography || useRobustSteganography;
      if (qrConfig != null && qrConfig.invisibleQr) {
        final qrData = _buildQrMetadata(qrConfig);
        outputImage = _embedQrCodeLSB(outputImage, qrData,
            channel: 'r'); // Use Red channel for QR
        forcePng = true;
      }

      return _encodeImageInOriginalFormat(
          outputImage, originalExtension, jpegQuality, forcePng);
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
    if (encrypt) dataToEmbed = _encryptBytes(fileBytes, password);
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
    if (totalBits > totalPixels) return image;
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
      String? qrData;

      // Check each channel (B, G, R) for any of our steganography types
      for (final channel in ['b', 'g', 'r']) {
        final result = _checkChannel(image, channel, password);
        if (result.signature != null) signature = result.signature;
        if (result.file != null) file = result.file;
        if (result.qrData != null) qrData = result.qrData;
      }

      final robustSignature = _extractRobustSignature(image);

      return AnalysisResult(
          signature: signature,
          robustSignature: robustSignature,
          file: file,
          qrData: qrData);
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
    if (type == 77 || type == 88) {
      return AnalysisResult(
          signature: _extractTextFromImage(image, type == 88, password,
              channel: channel));
    }
    if (type == 70 || type == 69) {
      return AnalysisResult(
          file: _extractFileFromImage(image, type == 69, password,
              channel: channel));
    }
    if (type == 81) {
      return AnalysisResult(
          qrData: _extractQrFromImage(image, channel: channel));
    }

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
      if (payloadLength <= 0 || payloadLength > 1024 * 1024) return null;
      final int payloadBytesNeeded = payloadLength + 2;
      final int remainingPixels = totalPixels - 48;
      if (payloadBytesNeeded * 8 > remainingPixels) return null;
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
      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          return '[ENCRYPTED] (Password required)';
        }
        final decrypted = _decryptBytes(payloadBytes, password);
        if (decrypted == null) {
          return '[ENCRYPTED] (Wrong password)';
        }
        payloadBytes = decrypted;
      }
      if (_crc16(payloadBytes) != extractedCrc) {
        return isEncrypted ? '[ENCRYPTED] (Wrong password)' : null;
      }
      return utf8.decode(payloadBytes, allowMalformed: true);
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
      if (filenameLength <= 0 ||
          filenameLength > 255 ||
          fileSize <= 0 ||
          fileSize > 50 * 1024 * 1024) return null;
      final int totalDataBytes = filenameLength + fileSize + 2;
      final int remainingPixels = totalPixels - 64;
      if (totalDataBytes * 8 > remainingPixels) return null;
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
      if (isEncrypted) {
        if (password == null || password.isEmpty) {
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        final decrypted = _decryptBytes(fileBytes, password);
        if (decrypted == null) {
          return ExtractedFileResult(
              fileName: filename, fileBytes: Uint8List(0), isEncrypted: true);
        }
        fileBytes = decrypted;
      }
      if (_crc16(fileBytes) != extractedCrc) {
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

  static String? _extractQrFromImage(img.Image image, {String channel = 'r'}) {
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
      final int qrLength =
          (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
      if (qrLength <= 0 || qrLength > 10240) {
        return null;
      }
      final int totalDataBytes = qrLength + 2;
      final int remainingPixels = totalPixels - 48;
      if (totalDataBytes * 8 > remainingPixels) {
        return null;
      }
      final int stride =
          (remainingPixels ~/ (totalDataBytes * 8)).clamp(1, 1000);
      currentByte = 0;
      bytes.clear();
      for (var i = 0; i < totalDataBytes * 8; i++) {
        final pixelIdx = 48 + (i * stride);
        final pixel = image.getPixel(pixelIdx % width, pixelIdx ~/ width);
        currentByte = (currentByte << 1) | _getChannelBit(pixel, channel);
        if ((i + 1) % 8 == 0) {
          bytes.add(currentByte);
          currentByte = 0;
        }
      }
      final qrBytes = bytes.sublist(0, qrLength);
      final extractedCrc = (bytes[qrLength] << 8) | bytes[qrLength + 1];
      if (_crc16(qrBytes) != extractedCrc) {
        return null;
      }
      return utf8.decode(qrBytes, allowMalformed: true);
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
      if (encryptedData.length < 16) return null;
      final iv = enc.IV(encryptedData.sublist(0, 16));
      final data = encryptedData.sublist(16);
      final keyBytes = sha256.convert(utf8.encode(password)).bytes;
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = encrypter.decryptBytes(enc.Encrypted(data), iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (_) {
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
      if (moduleCount == 0)
        return img.Image(width: size, height: size, numChannels: 4);
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

  static img.Image _embedQrCodeLSB(img.Image image, String qrData,
      {String channel = 'r'}) {
    try {
      final qrBytes = utf8.encode(qrData);
      final crc = _crc16(qrBytes);
      final headerBytes = utf8.encode('SQ');
      final fullPayload = BytesBuilder();
      fullPayload.add(headerBytes);
      final length = qrBytes.length;
      fullPayload.add([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF
      ]);
      fullPayload.add(qrBytes);
      fullPayload.add([(crc >> 8) & 0xFF, crc & 0xFF]);
      final payload = fullPayload.toBytes();
      final totalBits = payload.length * 8;
      final totalPixels = image.width * image.height;
      if (totalBits > totalPixels) return image;
      const int headerBits = 48;
      for (var i = 0; i < headerBits && i < totalBits; i++) {
        final bit = (payload[i ~/ 8] >> (7 - (i % 8))) & 1;
        final pixel = image.getPixel(i % image.width, i ~/ image.width);
        _setChannelBit(pixel, channel, bit);
      }
      final remainingBits = totalBits - headerBits;
      if (remainingBits > 0) {
        final stride =
            ((totalPixels - headerBits) ~/ remainingBits).clamp(1, 1000);
        for (var i = 0; i < remainingBits; i++) {
          final bitIdx = headerBits + i;
          final bit = (payload[bitIdx ~/ 8] >> (7 - (bitIdx % 8))) & 1;
          final pixelIdx = headerBits + (i * stride);
          if (pixelIdx >= totalPixels) break;
          final pixel =
              image.getPixel(pixelIdx % image.width, pixelIdx ~/ image.width);
          _setChannelBit(pixel, channel, bit);
        }
      }
      return image;
    } catch (e) {
      return image;
    }
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
    if (bitmapFont != null)
      img.drawString(textImage, watermarkText,
          font: bitmapFont,
          x: 0,
          y: (12 * (placement.fontSize / 24)).round(),
          color: placement.color);
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
      QrWatermarkConfig? qrConfig}) {
    if (transparency >= 100) return;
    final placements = _buildPlacements(
        width: image.width,
        height: image.height,
        watermarkText: watermarkText,
        transparency: transparency,
        density: density,
        useRandomColor: useRandomColor,
        selectedColorValue: selectedColorValue,
        fontSize: fontSize.round(),
        font: font);
    final stampCache = <String, img.Image>{};
    for (final placement in placements) {
      final jitterX =
          ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5)).round();
      final jitterY =
          ((antiAiLevel / 100.0) * 10 * (_random.nextDouble() - 0.5)).round();
      var stamp = stampCache.putIfAbsent(
          '${placement.angle.round()}-${placement.colorKey}',
          () => _buildWatermarkStamp(
              watermarkText, placement, preRenderedStamps));
      if (antiAiLevel > 0) {
        stamp = stamp.clone();
        for (final pixel in stamp) {
          if (pixel.a > 0)
            pixel.a = (pixel.a +
                    (antiAiLevel / 100.0) * 40 * (_random.nextDouble() - 0.5))
                .clamp(0, 255)
                .toInt();
        }
      }
      img.compositeImage(image, stamp,
          dstX: placement.x + jitterX,
          dstY: placement.y + jitterY,
          blend: img.BlendMode.alpha);
    }
    if (qrConfig != null && qrConfig.visibleQr) {
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
        img.compositeImage(image, qrImage,
            dstX: x, dstY: y, blend: img.BlendMode.alpha);
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
      required WatermarkFont font}) {
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
    }
    var extra = targetCount * 4;
    while (placements.length < targetCount && extra-- > 0) {
      final p = _tryPlacementAnywhere(
          width: width,
          height: height,
          watermarkText: watermarkText,
          colorPool: colorPool,
          fontSize: fontSize,
          font: font);
      if (p != null) placements.add(p);
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
    if (targetSize == null || max(image.width, image.height) <= targetSize)
      return image;
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
    if (stegan || ext.toLowerCase() == '.png' || ext.toLowerCase() == '.webp')
      return Uint8List.fromList(img.encodePng(image, level: 2));
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
    String? steganographyPassword,
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
        Map<String, Uint8List>? stamps;
        if (!font.isBitmap) {
          final bytes = await _renderTextWithFlutterCanvas(
              text: watermarkText,
              font: font,
              fontSize: fontSize.round(),
              color: const ui.Color.fromARGB(255, 255, 255, 255));
          stamps = {'${font.fontFamily}-${fontSize.round()}': bytes};
        }
        _applyWatermarkField(watermarked, watermarkText, transparency, density,
            useRandomColor, selectedColorValue, fontSize, font, stamps,
            antiAiLevel: antiAiLevel, qrConfig: qrConfig);
        if (useRobustSteganography) {
          watermarked = _embedRobustSignature(watermarked, watermarkText);
        }
        if (useSteganography) {
          if (hiddenFileName != null && hiddenFileBytes != null) {
            watermarked = _embedFileIntoImage(
                watermarked, hiddenFileName, hiddenFileBytes,
                password: steganographyPassword, channel: 'g');
          }
          // Always embed watermark text as LSB if steganography is enabled (Blue channel)
          watermarked = _embedLSB(watermarked, watermarkText,
              password: steganographyPassword, channel: 'b');
        }
        if (qrConfig != null && qrConfig.invisibleQr) {
          watermarked = _embedQrCodeLSB(watermarked, _buildQrMetadata(qrConfig),
              channel: 'r');
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
        onProgress?.call(
            0.3 + (processed / (pageCount + 1)) * 0.6, 'Page $processed...');
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
              hiddenFileName != null ||
              (qrConfig?.invisibleQr == true)) &&
          preview != null) {
        final analysis = analyzeImage(preview, password: steganographyPassword);

        if (useSteganography ||
            hiddenFileName != null ||
            (qrConfig?.invisibleQr == true)) {
          bool allVerified = true;
          if (hiddenFileName != null) {
            allVerified &= (analysis.file != null &&
                analysis.file!.fileName == hiddenFileName);
          }
          if (qrConfig?.invisibleQr == true) {
            allVerified &=
                (analysis.qrData != null && analysis.qrData!.isNotEmpty);
          }
          if (useSteganography) {
            allVerified &= (analysis.signature == watermarkText);
          }
          verified = allVerified;
        }

        if (useRobustSteganography) {
          robustVerified = analysis.robustSignature == watermarkText;
        }
      }
      return ProcessResult(
          outputPath: path,
          outputBytes: out,
          previewBytes: preview,
          originalBytes: firstPageOriginal,
          steganographyVerified: verified,
          robustVerified: robustVerified);
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
}
