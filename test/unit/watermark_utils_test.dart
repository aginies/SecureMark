import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:secure_mark/utils/watermark_utils.dart';

void main() {
  group('sanitizeFilePrefix', () {
    test('keeps a plain prefix untouched', () {
      expect(WatermarkUtils.sanitizeFilePrefix('securemark-'), 'securemark-');
      expect(WatermarkUtils.sanitizeFilePrefix('my prefix 42'), 'my prefix 42');
    });

    test('strips path separators, drive colons and control characters', () {
      expect(WatermarkUtils.sanitizeFilePrefix('../../etc/'), '....etc');
      expect(
          WatermarkUtils.sanitizeFilePrefix('..\\..\\windows'), '....windows');
      expect(WatermarkUtils.sanitizeFilePrefix('a/b\\c:d'), 'abcd');
      expect(WatermarkUtils.sanitizeFilePrefix('a\u0000b\u0007c'), 'abc');
      expect(WatermarkUtils.sanitizeFilePrefix('line1\nline2'), 'line1line2');
    });
  });

  group('outputPath', () {
    test('normal prefix still works', () {
      final out = WatermarkUtils.outputPath(
          '/home/user/photos/vacation.jpg', '.jpg', false, 'securemark-');
      expect(out, '/home/user/photos/securemark-vacation.jpg');
    });

    test('hostile prefixes can never escape the input directory', () {
      final input = '/home/user/photos/vacation.jpg';
      final hostile = [
        '../../evil/',
        '..\\..\\windows\\',
        '/etc/cron.d/',
        'a/../../b',
        'x\u0000y',
        'C:/ProgramData/',
      ];
      for (final pref in hostile) {
        final out = WatermarkUtils.outputPath(input, '.jpg', false, pref);
        expect(p.dirname(out), p.dirname(input),
            reason: 'prefix must not change the output directory: $pref');
      }
    });
  });
}
