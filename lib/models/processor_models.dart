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
    this.width,
    this.height,
    this.appliedFeatures = const [],
  });

  final String outputPath;
  final Uint8List outputBytes;
  final Uint8List? previewBytes;
  final Uint8List? originalBytes;
  final Uint8List? heatmapBytes;
  final bool steganographyVerified;
  final bool robustVerified;
  final bool isPdf;
  final int? width;
  final int? height;
  final List<String> appliedFeatures;
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

/// Result of analyzing a single file from a batch/ZIP
class FileAnalysisItem {
  const FileAnalysisItem({
    required this.fileName,
    required this.analysis,
    this.error,
  });

  final String fileName;
  final AnalysisResult? analysis;
  final String? error;

  bool get hasError => error != null;
  bool get hasSignature =>
      analysis?.signature != null || analysis?.robustSignature != null;
  bool get hasHiddenFile => analysis?.file != null;
  bool get hasIntegrity => analysis?.integrityVerified == true;
  String? get senderKey => analysis?.senderPublicKey;
}

/// Result of batch analysis (ZIP or multiple files)
class BatchAnalysisResult {
  const BatchAnalysisResult({
    required this.items,
    this.zipPassword,
  });

  final List<FileAnalysisItem> items;
  final String? zipPassword;

  int get totalFiles => items.length;
  int get filesWithSignatures =>
      items.where((item) => item.hasSignature).length;
  int get filesWithHiddenFiles =>
      items.where((item) => item.hasHiddenFile).length;
  int get filesWithIntegrity => items.where((item) => item.hasIntegrity).length;
  int get filesWithErrors => items.where((item) => item.hasError).length;

  /// Groups files by sender public key
  Map<String, List<FileAnalysisItem>> groupBySender() {
    final Map<String, List<FileAnalysisItem>> groups = {};
    for (final item in items) {
      final key = item.senderKey ?? 'unsigned';
      groups.putIfAbsent(key, () => []).add(item);
    }
    return groups;
  }
}
