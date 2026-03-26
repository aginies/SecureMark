import 'package:path/path.dart' as p;

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
  missingSteganographySignature,
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

    // Check for resolution limit error
    // Matches: "Image resolution 16320x7532 (123.0 MP) exceeds..."
    if (message.startsWith('Image resolution') ||
        message.contains('exceeds maximum') ||
        message.contains('MP)')) {
      return message;
    }

    // Check for Samsung TIFF-wrapped JPEG error
    if (message.contains('Samsung') ||
        message.contains('TIFF-wrapped JPEG') ||
        message.contains('photo editor')) {
      return message;
    }

    switch (type) {
      case WatermarkErrorType.unsupportedFileType:
        return 'This file type is not supported. Please use JPG, PNG, or PDF files.';
      case WatermarkErrorType.fileTooLarge:
        return 'File is too large (max 100MB). Please use a smaller file.';
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
      case WatermarkErrorType.missingSteganographySignature:
        return 'Custom Steganography Signature cannot be empty when steganography is enabled.';
      case WatermarkErrorType.unknownError:
        return 'An unexpected error occurred while processing the file.';
    }
  }
}
