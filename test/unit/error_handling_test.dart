import 'package:flutter_test/flutter_test.dart';
import 'package:secure_mark/watermark_processor.dart';

void main() {
  group('WatermarkError Tests', () {
    test('Should construct with basic properties', () {
      const error = WatermarkError(
        type: WatermarkErrorType.fileNotFound,
        message: 'Original message',
        filePath: 'path/to/file.jpg',
      );

      expect(error.type, WatermarkErrorType.fileNotFound);
      expect(error.message, 'Original message');
      expect(error.filePath, 'path/to/file.jpg');
      expect(error.toString(), contains('Original message'));
      expect(error.toString(), contains('file.jpg'));
    });

    test('Verify all user-friendly error messages', () {
      const types = WatermarkErrorType.values;
      for (final type in types) {
        final error = WatermarkError(type: type, message: 'test');
        expect(error.userMessage, isNotEmpty,
            reason: 'Type $type should have a user message');
      }
    });

    test('Specific user message content checks', () {
      expect(
          const WatermarkError(
                  type: WatermarkErrorType.unsupportedFileType, message: '')
              .userMessage,
          contains('JPG, PNG, or PDF'));

      expect(
          const WatermarkError(
                  type: WatermarkErrorType.fileTooLarge, message: '')
              .userMessage,
          contains('File is too large'));

      expect(
          const WatermarkError(
                  type: WatermarkErrorType.operationCancelled, message: '')
              .userMessage,
          contains('cancelled'));
    });
  });
}
