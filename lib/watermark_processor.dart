import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sync;

import 'font_manager.dart';

final Random _random = Random();
const double _angleStepDegrees = 15;
const int _randomColorPoolSize = 6;
const int _maxFileSize = 100 * 1024 * 1024; // 100MiB
const int _maxFilesInBatch = 100;

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
  });

  final String outputPath;
  final Uint8List outputBytes;
  final Uint8List? previewBytes;
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
  static final Map<String, ProcessResult> _resultCache = <String, ProcessResult>{};
  
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
    int? targetSize = 1280,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    bool rasterizePdf = false,
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
          onProgress: onProgress,
          cancellationToken: cancellationToken,
        );
      } else if (extension == '.jpg' || extension == '.jpeg' || extension == '.png' || extension == '.webp') {
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
            message: 'File size ${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB exceeds limit of ${(_maxFileSize / (1024 * 1024)).round()}MB',
            filePath: file.path,
          ),
        );
      }

      // Check file extension
      final extension = p.extension(file.path).toLowerCase();
      const supportedExtensions = {'.jpg', '.jpeg', '.png', '.webp', '.pdf', '.heic', '.heif'};
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
  ) {
    return '$filePath-$transparency-$density-$watermarkText-$useRandomColor-$selectedColorValue-$fontSize-${font.fontFamily}-$jpegQuality-$targetSize-$includeTimestamp-$preserveMetadata-$rasterizePdf';
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

  /// Process multiple files with progress reporting and cancellation support
  static Future<List<ProcessResult>> processMultipleFiles({
    required List<File> files,
    required double transparency,
    required double density,
    required String watermarkText,
    required bool useRandomColor,
    required int selectedColorValue,
    required double fontSize,
    int jpegQuality = 75,
    int? targetSize = 1280,
    bool includeTimestamp = false,
    bool preserveMetadata = false,
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    if (files.length > _maxFilesInBatch) {
      throw const WatermarkError(
        type: WatermarkErrorType.unknownError,
        message: 'Too many files in batch (max $_maxFilesInBatch)',
      );
    }

    final results = <ProcessResult>[];
    final totalFiles = files.length;

    for (var i = 0; i < totalFiles; i++) {
      if (cancellationToken?.isCancelled == true) {
        throw const WatermarkError(
          type: WatermarkErrorType.operationCancelled,
          message: 'Batch processing was cancelled',
        );
      }

      try {
        final fileProgress = i / totalFiles;
        onProgress?.call(fileProgress, 'Processing file ${i + 1} of $totalFiles...');

        final result = await processFile(
          file: files[i],
          transparency: transparency,
          density: density,
          watermarkText: watermarkText,
          useRandomColor: useRandomColor,
          selectedColorValue: selectedColorValue,
          fontSize: fontSize,
          jpegQuality: jpegQuality,
          targetSize: targetSize,
          includeTimestamp: includeTimestamp,
          preserveMetadata: preserveMetadata,
          onProgress: (progress, message) {
            final totalProgress = fileProgress + (progress / totalFiles);
            onProgress?.call(totalProgress, message);
          },
          cancellationToken: cancellationToken,
        );

        results.add(result);
      } catch (e) {
        // Continue processing other files even if one fails
        debugPrint('Failed to process ${files[i].path}: $e');
        continue;
      }
    }

    onProgress?.call(1.0, 'Batch processing complete');
    return results;
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
      
      final outputPath = _outputPath(file.path, outputExtension, includeTimestamp);

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: outputBytes,
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
          ),
        );
      } catch (e, stackTrace) {
        debugPrint('Vector engine error: $e');
        debugPrint('Stack trace: $stackTrace');
        onProgress?.call(0.3, 'Vector engine failed ($e), falling back to raster engine...');
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
      
      final outputPath = _outputPath(file.path, '.pdf', includeTimestamp);

      // Generate a preview of the first page using the existing Printing logic
      // Note: Printing.raster must be called on the main isolate as it uses platform channels
      final preview = await Printing.raster(outputBytes, pages: [0], dpi: 72).first;
      final previewBytes = await preview.toPng();

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: previewBytes,
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
  }) {
    sync.PdfDocument document;
    try {
      document = sync.PdfDocument(inputBytes: inputBytes);
    } catch (e) {
      // If direct loading fails, try repairing common cross-reference issues
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'The PDF file appears to be malformed or corrupted. Error: $e',
        originalError: e,
      );
    }

    // Sanitize metadata if requested, or add our app tag
    if (!preserveMetadata) {
      document.documentInformation.author = '';
      document.documentInformation.creator = 'SecureMark (https://github.com/aginies/SecureMark)';
      document.documentInformation.keywords = 'SecureMark, Watermark, Security';
      document.documentInformation.producer = 'SecureMark';
      document.documentInformation.subject = '';
      document.documentInformation.title = '';
    } else {
      // Even if preserving, add our tag to creator if it's empty
      if (document.documentInformation.creator.isEmpty) {
        document.documentInformation.creator = 'SecureMark (https://github.com/aginies/SecureMark)';
      }
    }
    
    final pageCount = document.pages.count;

    // Color and transparency
    final alpha = (100 - transparency).clamp(10, 90) / 100;
    final pdfFont = sync.PdfStandardFont(sync.PdfFontFamily.helvetica, fontSize);

    for (var i = 0; i < pageCount; i++) {
      final page = document.pages[i];
      final pageSize = page.size;
      final graphics = page.graphics;

      // Draw multiple watermarks based on density
      final targetCount = _watermarkCount(pageSize.width.toInt(), pageSize.height.toInt(), density);
      final columns = max<int>(2, sqrt(targetCount * (pageSize.width / max<double>(1.0, pageSize.height))).round());
      final rows = max<int>(2, (targetCount / columns).ceil());
      
      final cellWidth = pageSize.width / columns;
      final cellHeight = pageSize.height / rows;

      for (var row = 0; row < rows; row++) {
        for (var col = 0; col < columns; col++) {
          graphics.save();
          
          // Resolve color for this instance (opaque, transparency handled by graphics state)
          final color = _resolveSyncfusionColor(useRandomColor, selectedColorValue);
          final brush = sync.PdfSolidBrush(color);

          // Randomize position within cell slightly
          final x = (col * cellWidth) + (_random.nextDouble() * (cellWidth * 0.3));
          final y = (row * cellHeight) + (_random.nextDouble() * (cellHeight * 0.3));
          final angle = _randomAngle();

          graphics.translateTransform(x, y);
          graphics.rotateTransform(angle);
          
          // Apply transparency globally to the graphics state
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

  static sync.PdfColor _resolveSyncfusionColor(bool useRandomColor, int selectedColorValue) {
    int r, g, b;
    if (useRandomColor) {
      final hue = _random.nextDouble() * 360;
      const double saturation = 0.8;
      const double value = 0.95;
      const double chroma = value * saturation;
      final x = chroma * (1 - (((hue / 60) % 2) - 1).abs());
      const double m = value - chroma;
      double rf, gf, bf;
      if (hue < 60) { rf = chroma; gf = x; bf = 0; }
      else if (hue < 120) { rf = x; gf = chroma; bf = 0; }
      else if (hue < 180) { rf = 0; gf = chroma; bf = x; }
      else if (hue < 240) { rf = 0; gf = x; bf = chroma; }
      else if (hue < 300) { rf = x; gf = 0; bf = chroma; }
      else { rf = chroma; gf = 0; bf = x; }
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
      final outputImage = img.Image.from(resized);

      if (preserveMetadata && !decoded.exif.isEmpty) {
        outputImage.exif = decoded.exif.clone();
      }

      // Add our app tag to the image metadata
      outputImage.textData ??= {};
      outputImage.textData!['Description'] = 'SecureMark (https://github.com/aginies/SecureMark)';
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
      );

      // Encode in the original format
      return _encodeImageInOriginalFormat(outputImage, originalExtension, jpegQuality);
    } catch (e) {
      if (e is WatermarkError) {
        rethrow;
      }
      throw WatermarkError(
        type: WatermarkErrorType.invalidImageData,
        message: 'Failed to render watermarked image',
        filePath: filePath,
        originalError: e,
      );
    }
  }

  static img.Image _buildWatermarkStamp(String watermarkText, _Placement placement) {
    final baseTextWidth = max(1, (watermarkText.length * 18 * (placement.fontSize / 24)).round());
    final baseTextHeight = (48 * (placement.fontSize / 24)).round();
    final textImage = img.Image(
      width: baseTextWidth,
      height: baseTextHeight,
      numChannels: 4,
    );
    textImage.clear(img.ColorRgba8(0, 0, 0, 0));
    textImage.backgroundColor = img.ColorRgba8(0, 0, 0, 0);

    // Select font based on the placement font type
    if (placement.font.isBitmap) {
      // Use bitmap font for Arial (legacy support)
      final bitmapFont = placement.font.getBitmapFont(placement.fontSize);
      if (bitmapFont != null) {
        img.drawString(
          textImage,
          watermarkText,
          font: bitmapFont,
          x: 0,
          y: (12 * (placement.fontSize / 24)).round(),
          color: placement.color,
        );
      }
    } else {
      // For Google Fonts, fall back to bitmap font for now
      // In a future enhancement, this could use TrueType font rendering
      final font = _getFontForSize(placement.fontSize);
      img.drawString(
        textImage,
        watermarkText,
        font: font,
        x: 0,
        y: (12 * (placement.fontSize / 24)).round(),
        color: placement.color,
      );
    }

    final rotated = img.copyRotate(
      textImage,
      angle: placement.angle,
      interpolation: img.Interpolation.linear,
    );
    rotated.backgroundColor = img.ColorRgba8(0, 0, 0, 0);
    return rotated;
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
  ) {
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
    );

    final stampCache = <String, img.Image>{};

    for (final placement in placements) {
      final stampKey = '${placement.angle.round()}-${placement.colorKey}';
      final stamp = stampCache.putIfAbsent(
        stampKey,
        () => _buildWatermarkStamp(watermarkText, placement),
      );
      img.compositeImage(
        image,
        stamp,
        dstX: placement.x,
        dstY: placement.y,
        blend: img.BlendMode.alpha,
      );
    }
  }

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
  }) {
    final placements = <_Placement>[];
    final targetCount = _watermarkCount(width, height, density);
    final alpha = _alphaFromTransparency(transparency);
    final colorPool = _buildColorPool(useRandomColor, selectedColorValue, alpha);
    final columns = max(2, sqrt(targetCount * (width / max(1, height))).round());
    final rows = max(2, (targetCount / columns).ceil());
    final cellWidth = max(1.0, width / columns.toDouble());
    final cellHeight = max(1.0, height / rows.toDouble());
    final cells = <Point<int>>[];

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        cells.add(Point<int>(column, row));
      }
    }
    cells.shuffle(_random);

    for (final cell in cells) {
      if (placements.length >= targetCount) {
        break;
      }

      final placement = _tryPlacementInCell(
        width: width,
        height: height,
        watermarkText: watermarkText,
        cellColumn: cell.x,
        cellRow: cell.y,
        cellWidth: cellWidth,
        cellHeight: cellHeight,
        colorPool: colorPool,
        fontSize: fontSize,
        font: font,
      );

      if (placement != null) {
        placements.add(placement);
      }
    }

    var extraAttempts = targetCount * 4;
    while (placements.length < targetCount && extraAttempts > 0) {
      extraAttempts -= 1;
      final placement = _tryPlacementAnywhere(
        width: width,
        height: height,
        watermarkText: watermarkText,
        colorPool: colorPool,
        fontSize: fontSize,
        font: font,
      );
      if (placement != null) {
        placements.add(placement);
      }
    }

    return placements;
  }

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
    for (var attempt = 0; attempt < 6; attempt++) {
      final angle = _randomAngle();
      final rotatedSize = _rotatedStampSize(watermarkText, fontSize, angle);
      if (rotatedSize.$1 >= width || rotatedSize.$2 >= height) {
        continue;
      }

      final minX = (cellColumn * cellWidth).floor();
      final maxX = min(
        width - 1,
        (((cellColumn + 1) * cellWidth).floor() - 1).clamp(-rotatedSize.$1 + 1, width - 1),
      );
      final minY = (cellRow * cellHeight).floor();
      final maxY = min(
        height - 1,
        (((cellRow + 1) * cellHeight).floor() - 1).clamp(-rotatedSize.$2 + 1, height - 1),
      );

      final relaxedMinX = max(-rotatedSize.$1 + 1, minX - (rotatedSize.$1 ~/ 3));
      final relaxedMinY = max(-rotatedSize.$2 + 1, minY - (rotatedSize.$2 ~/ 3));

      if (maxX < relaxedMinX || maxY < relaxedMinY) {
        continue;
      }

      final x = relaxedMinX + _random.nextInt(maxX - relaxedMinX + 1);
      final y = relaxedMinY + _random.nextInt(maxY - relaxedMinY + 1);
      final resolvedColor = _pickColor(colorPool);
      return _Placement(
        x: x,
        y: y,
        fontSize: fontSize,
        angle: angle,
        colorKey: resolvedColor.key,
        color: resolvedColor.color,
        font: font,
      );
    }

    return null;
  }

  static _Placement? _tryPlacementAnywhere({
    required int width,
    required int height,
    required String watermarkText,
    required List<_ResolvedColor> colorPool,
    required int fontSize,
    required WatermarkFont font,
  }) {
    for (var attempt = 0; attempt < 12; attempt++) {
      final angle = _randomAngle();
      final rotatedSize = _rotatedStampSize(watermarkText, fontSize, angle);
      if (rotatedSize.$1 >= width || rotatedSize.$2 >= height) {
        continue;
      }

      final minX = -rotatedSize.$1 + 1;
      final maxX = width - 1;
      final minY = -rotatedSize.$2 + 1;
      final maxY = height - 1;
      final x = minX + _random.nextInt(maxX - minX + 1);
      final y = minY + _random.nextInt(maxY - minY + 1);
      final resolvedColor = _pickColor(colorPool);
      return _Placement(
        x: x,
        y: y,
        fontSize: fontSize,
        angle: angle,
        colorKey: resolvedColor.key,
        color: resolvedColor.color,
        font: font,
      );
    }

    return null;
  }

  static (int, int) _rotatedStampSize(String watermarkText, int fontSize, double angle) {
    final scale = fontSize / 24.0;
    final baseWidth = max(1, (watermarkText.length * 18 * scale).round());
    final baseHeight = (48 * scale).round();
    final scaledWidth = max(1, baseWidth);
    final scaledHeight = max(1, baseHeight);
    final radians = angle * pi / 180.0;
    final rotatedWidth =
        (scaledWidth * cos(radians).abs() + scaledHeight * sin(radians).abs()).ceil();
    final rotatedHeight =
        (scaledWidth * sin(radians).abs() + scaledHeight * cos(radians).abs()).ceil();
    return (rotatedWidth, rotatedHeight);
  }

  static int _watermarkCount(int width, int height, double density) {
    final area = width * height;
    final baseDensity = area / 18000;
    final densityFactor = (density / 50).clamp(0.4, 2.0);
    return max(8, (baseDensity * 2.69 * densityFactor).round());
  }

  static int _alphaFromTransparency(double transparency) {
    final opacity = (100 - transparency).clamp(10, 90) / 100;
    return (opacity * 255).round();
  }

  static img.Image _resizeToTarget(img.Image image, int? targetSize) {
    if (targetSize == null) {
      return image;
    }

    final width = image.width;
    final height = image.height;
    final longestSide = max(width, height);

    if (longestSide <= targetSize) {
      return image; // Do not upscale
    }

    // Downscale while preserving aspect ratio
    final scale = targetSize / longestSide;
    final newWidth = (width * scale).round();
    final newHeight = (height * scale).round();

    try {
      return img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );
    } catch (e) {
      throw WatermarkError(
        type: WatermarkErrorType.memoryLimitExceeded,
        message: 'Not enough memory to resize image',
        originalError: e,
      );
    }
  }

  static Uint8List _encodePngForSharing(img.Image image) {
    return Uint8List.fromList(img.encodePng(image, level: 2));
  }

  /// Encode image in the original format to preserve file type
  static Uint8List _encodeImageInOriginalFormat(img.Image image, String extension, int jpegQuality) {
    switch (extension.toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
      case '.png':
        return Uint8List.fromList(img.encodePng(image, level: 2));
      case '.webp':
        // WebP encoding may not be available in current image package version
        // Fall back to PNG encoding for WebP files
        return Uint8List.fromList(img.encodePng(image, level: 2));
      default:
        // Default to PNG for unsupported formats
        return Uint8List.fromList(img.encodePng(image, level: 2));
    }
  }

  static double _randomAngle() {
    final stepCount = (360 / _angleStepDegrees).round();
    return _random.nextInt(stepCount) * _angleStepDegrees;
  }

  static List<_ResolvedColor> _buildColorPool(
    bool useRandomColor,
    int selectedColorValue,
    int alpha,
  ) {
    if (!useRandomColor) {
      final color = _resolveWatermarkColor(false, selectedColorValue, alpha);
      return <_ResolvedColor>[
        _ResolvedColor(key: (alpha << 24) | (selectedColorValue & 0x00FFFFFF), color: color),
      ];
    }

    return List<_ResolvedColor>.generate(_randomColorPoolSize, (index) {
      return _ResolvedColor(
        key: index,
        color: _randomWatermarkColor(alpha),
      );
    });
  }

  static _ResolvedColor _pickColor(List<_ResolvedColor> colorPool) {
    return colorPool[_random.nextInt(colorPool.length)];
  }

  static img.Color _randomWatermarkColor(int alpha) {
    final hue = _random.nextDouble() * 360;
    const double saturation = 0.8;
    const double value = 0.95;
    const double chroma = value * saturation;
    final x = chroma * (1 - (((hue / 60) % 2) - 1).abs());
    const double m = value - chroma;

    double red;
    double green;
    double blue;

    if (hue < 60) {
      red = chroma;
      green = x;
      blue = 0;
    } else if (hue < 120) {
      red = x;
      green = chroma;
      blue = 0;
    } else if (hue < 180) {
      red = 0;
      green = chroma;
      blue = x;
    } else if (hue < 240) {
      red = 0;
      green = x;
      blue = chroma;
    } else if (hue < 300) {
      red = x;
      green = 0;
      blue = chroma;
    } else {
      red = chroma;
      green = 0;
      blue = x;
    }

    return img.ColorRgba8(
      ((red + m) * 255).round(),
      ((green + m) * 255).round(),
      ((blue + m) * 255).round(),
      alpha,
    );
  }

  static img.Color _resolveWatermarkColor(
    bool useRandomColor,
    int selectedColorValue,
    int alpha,
  ) {
    if (useRandomColor) {
      return _randomWatermarkColor(alpha);
    }

    final red = (selectedColorValue >> 16) & 0xFF;
    final green = (selectedColorValue >> 8) & 0xFF;
    final blue = selectedColorValue & 0xFF;
    return img.ColorRgba8(red, green, blue, alpha);
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
    ProgressCallback? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    try {
      final doc = pw.Document();
      Uint8List? preview;
      var hasPages = false;
      var pageCount = 0;
      var processedPages = 0;

      // Use a safe DPI for fallback processing
      const double fallbackDpi = 150;

      await for (final page in Printing.raster(inputBytes, dpi: fallbackDpi)) {
        if (cancellationToken?.isCancelled == true) {
          throw const WatermarkError(
            type: WatermarkErrorType.operationCancelled,
            message: 'Operation cancelled during PDF fallback processing',
          );
        }

        hasPages = true;
        pageCount++;

        final pngBytes = await page.toPng();
        final decoded = img.decodeImage(pngBytes);

        final watermarked = img.Image.from(decoded!);
        _applyWatermarkField(
          watermarked,
          watermarkText,
          transparency,
          density,
          useRandomColor,
          selectedColorValue,
          fontSize,
          font,
        );

        final encoded = _encodePngForSharing(watermarked);
        preview ??= encoded;

        final provider = pw.MemoryImage(encoded);
        final format = PdfPageFormat(
          page.width.toDouble(),
          page.height.toDouble(),
        );

        doc.addPage(
          pw.Page(
            pageFormat: format,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.SizedBox.expand(
              child: pw.Image(provider, fit: pw.BoxFit.fill),
            ),
          ),
        );

        processedPages++;
        onProgress?.call(0.3 + (processedPages / (pageCount + 1)) * 0.6, 'Processing page $processedPages (fallback)...');
      }

      if (!hasPages) {
        throw WatermarkError(
          type: WatermarkErrorType.invalidPdfData,
          message: 'PDF contains no readable pages in fallback mode',
          filePath: file.path,
        );
      }

      final outputBytes = await doc.save();
      final outputPath = _outputPath(file.path, '.pdf', includeTimestamp);

      return ProcessResult(
        outputPath: outputPath,
        outputBytes: outputBytes,
        previewBytes: preview,
      );
    } catch (e) {
      throw WatermarkError(
        type: WatermarkErrorType.invalidPdfData,
        message: 'Completely failed to process PDF (both vector and raster engines)',
        filePath: file.path,
        originalError: e,
      );
    }
  }

  static String _outputPath(String originalPath, String targetExtension, [bool includeTimestamp = false]) {
    final directory = p.dirname(originalPath);
    final baseName = p.basenameWithoutExtension(originalPath);

    String suffix = '';
    if (includeTimestamp) {
      final now = DateTime.now();
      suffix = '-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
               '-${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
    }

    return p.join(directory, 'securemark-$baseName$suffix$targetExtension');
  }

  static String _resolvedWatermarkText(String userText) {
    final now = DateTime.now();
    final date = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      return '$date $time';
    }
    return '$trimmed $date $time';
  }
  }

