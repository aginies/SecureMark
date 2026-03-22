import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:secure_mark/font_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('WatermarkFont Enum Tests', () {
    test('Should have exactly 16 fonts', () {
      expect(WatermarkFont.values.length, 16);
    });

    test('Verify all font identifiers are unique', () {
      final identifiers =
          WatermarkFont.values.map((f) => f.getFontIdentifier()).toSet();
      expect(identifiers.length, WatermarkFont.values.length);
    });

    test('getTextStyle returns valid TextStyle for each source', () {
      for (final font in WatermarkFont.values) {
        // Skip Google fonts in unit tests as they trigger asset/network lookups
        if (font.source == FontSource.google) continue;

        final style = font.getTextStyle(fontSize: 20);
        expect(style, isA<TextStyle>());
        expect(style.fontSize, 20);

        if (font.source == FontSource.bitmap ||
            font.source == FontSource.asset) {
          expect(style.fontFamily, isNotNull);
        }
      }
    });

    test('getBitmapFont size selection logic', () {
      const arial = WatermarkFont.arial;
      expect(arial.isBitmap, isTrue);

      // Small
      expect(arial.getBitmapFont(10), isNotNull);
      // Medium
      expect(arial.getBitmapFont(24), isNotNull);
      // Large
      expect(arial.getBitmapFont(48), isNotNull);

      // Non-bitmap fonts should return null
      expect(WatermarkFont.roboto.getBitmapFont(24), isNull);
    });
  });

  group('FontManager Class Tests', () {
    test('getDefaultFont should return Arial', () {
      expect(FontManager.getDefaultFont(), WatermarkFont.arial);
    });

    test('getFontByName is case insensitive and handles invalid names', () {
      expect(FontManager.getFontByName('ARIAL'), WatermarkFont.arial);
      expect(FontManager.getFontByName('roboto'), WatermarkFont.roboto);
      expect(FontManager.getFontByName('NonExistent'), isNull);
    });

    test('Category getters return non-empty lists', () {
      expect(FontManager.googleFonts, isNotEmpty);
      expect(FontManager.assetFonts, isNotEmpty);
      expect(FontManager.bitmapFonts, isNotEmpty);
      expect(FontManager.professionalFonts, isNotEmpty);
      expect(FontManager.modernFonts, isNotEmpty);
      expect(FontManager.monospaceFonts, isNotEmpty);
    });

    test('isFontAvailable returns true for all (mocked for now)', () async {
      for (final font in WatermarkFont.values) {
        expect(await FontManager.isFontAvailable(font), isTrue);
      }
    });
  });
}
