import '../watermark_processor.dart';

class ProcessedFile {
  const ProcessedFile({
    required this.sourcePath,
    required this.result,
  });

  final String sourcePath;
  final ProcessResult result;
}
