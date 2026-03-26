import 'dart:typed_data';

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
    this.integrityVerified = false,
    this.senderPublicKey,
  });

  final String? signature;
  final String? robustSignature;
  final ExtractedFileResult? file;
  final VerificationResult? verification;
  final bool integrityVerified;
  final String? senderPublicKey;
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

class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.error,
    this.pageCount = 0,
  });

  final bool isValid;
  final dynamic error;
  final int pageCount;
}
