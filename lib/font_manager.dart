import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

enum FontSource {
  bitmap,   // System bitmap fonts
  google,   // Google Fonts
  asset,    // Custom TTF files in assets
}

enum WatermarkFont {
  arial('Arial', 'Arial (System Default)', true, FontSource.bitmap),
  roboto('Roboto', 'Roboto (Modern)', false, FontSource.google),
  openSans('Open Sans', 'Open Sans (Clean)', false, FontSource.google),
  lato('Lato', 'Lato (Professional)', false, FontSource.google),
  montserrat('Montserrat', 'Montserrat (Bold)', false, FontSource.google),
  poppins('Poppins', 'Poppins (Rounded)', false, FontSource.google),
  notoSans('Noto Sans', 'Noto Sans (Universal)', false, FontSource.google),
  sourceCodePro('Source Code Pro', 'Source Code Pro (Monospace)', false, FontSource.google),
  playfairDisplay('Playfair Display', 'Playfair Display (Elegant)', false, FontSource.google),
  oswald('Oswald', 'Oswald (Strong)', false, FontSource.google),
  // Custom asset fonts (your actual font files)
  customRoboto('CustomRoboto', 'Roboto (Custom TTF)', false, FontSource.asset),
  customOpenSans('CustomOpenSans', 'Open Sans (Custom TTF)', false, FontSource.asset),
  charis('Charis', 'Charis SIL (Serif)', false, FontSource.asset),
  liberationMono('LiberationMono', 'Liberation Mono (Monospace)', false, FontSource.asset),
  liberationSerif('LiberationSerif', 'Liberation Serif (Traditional)', false, FontSource.asset),
  vera('Vera', 'Bitstream Vera Sans', false, FontSource.asset);

  const WatermarkFont(this.fontFamily, this.displayName, this.isBitmap, this.source);

  final String fontFamily;
  final String displayName;
  final bool isBitmap; // Whether it uses bitmap fonts for watermarking
  final FontSource source;

  /// Get TextStyle for UI preview
  TextStyle getTextStyle({double fontSize = 16, FontWeight? fontWeight}) {
    switch (source) {
      case FontSource.bitmap:
        return TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
      
      case FontSource.google:
        switch (this) {
          case WatermarkFont.roboto:
            return GoogleFonts.roboto(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.openSans:
            return GoogleFonts.openSans(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.lato:
            return GoogleFonts.lato(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.montserrat:
            return GoogleFonts.montserrat(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.poppins:
            return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.notoSans:
            return GoogleFonts.notoSans(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.sourceCodePro:
            return GoogleFonts.sourceCodePro(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.playfairDisplay:
            return GoogleFonts.playfairDisplay(fontSize: fontSize, fontWeight: fontWeight);
          case WatermarkFont.oswald:
            return GoogleFonts.oswald(fontSize: fontSize, fontWeight: fontWeight);
          default:
            return TextStyle(
              fontFamily: fontFamily,
              fontSize: fontSize,
              fontWeight: fontWeight,
            );
        }
      
      case FontSource.asset:
        return TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
        );
    }
  }

  /// Get bitmap font for watermarking (for Arial) or null for TrueType fonts
  img.BitmapFont? getBitmapFont(int fontSize) {
    if (!isBitmap) return null;
    
    // Only Arial uses bitmap fonts for backward compatibility and performance
    if (fontSize <= 18) return img.arial14;
    if (fontSize <= 32) return img.arial24;
    return img.arial48;
  }

  /// Get font path or family name for TrueType watermarking
  String getFontIdentifier() {
    switch (this) {
      case WatermarkFont.arial:
        return 'Arial';
      case WatermarkFont.roboto:
        return 'Roboto';
      case WatermarkFont.openSans:
        return 'OpenSans';
      case WatermarkFont.lato:
        return 'Lato';
      case WatermarkFont.montserrat:
        return 'Montserrat';
      case WatermarkFont.poppins:
        return 'Poppins';
      case WatermarkFont.notoSans:
        return 'NotoSans';
      case WatermarkFont.sourceCodePro:
        return 'SourceCodePro';
      case WatermarkFont.playfairDisplay:
        return 'PlayfairDisplay';
      case WatermarkFont.oswald:
        return 'Oswald';
    }
  }
}

class FontManager {
  static const List<WatermarkFont> availableFonts = WatermarkFont.values;

  static WatermarkFont getDefaultFont() => WatermarkFont.arial;

  static WatermarkFont? getFontByName(String name) {
    try {
      return WatermarkFont.values.firstWhere(
        (font) => font.fontFamily.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Check if font is available
  static Future<bool> isFontAvailable(WatermarkFont font) async {
    switch (font.source) {
      case FontSource.bitmap:
        return true; // System fonts are always available
      case FontSource.google:
        // Google Fonts require internet for first download
        return true;
      case FontSource.asset:
        // Asset fonts are available if TTF files exist
        // For now assume they're available - could add file existence check
        return true;
    }
  }

  /// Get fonts by source type
  static List<WatermarkFont> get googleFonts => WatermarkFont.values
      .where((font) => font.source == FontSource.google)
      .toList();

  static List<WatermarkFont> get assetFonts => WatermarkFont.values
      .where((font) => font.source == FontSource.asset)
      .toList();

  static List<WatermarkFont> get bitmapFonts => WatermarkFont.values
      .where((font) => font.source == FontSource.bitmap)
      .toList();

  /// Get appropriate fonts for different categories
  static List<WatermarkFont> get professionalFonts => [
    WatermarkFont.arial,
    WatermarkFont.roboto,
    WatermarkFont.customRoboto,
    WatermarkFont.openSans,
    WatermarkFont.customOpenSans,
    WatermarkFont.lato,
    WatermarkFont.notoSans,
    WatermarkFont.vera,
  ];

  static List<WatermarkFont> get modernFonts => [
    WatermarkFont.montserrat,
    WatermarkFont.poppins,
    WatermarkFont.roboto,
    WatermarkFont.customRoboto,
    WatermarkFont.oswald,
    WatermarkFont.vera,
  ];

  static List<WatermarkFont> get decorativeFonts => [
    WatermarkFont.playfairDisplay,
    WatermarkFont.oswald,
    WatermarkFont.montserrat,
    WatermarkFont.charis,
  ];

  static List<WatermarkFont> get monospaceFonts => [
    WatermarkFont.sourceCodePro,
    WatermarkFont.liberationMono,
  ];

  static List<WatermarkFont> get serifFonts => [
    WatermarkFont.charis,
    WatermarkFont.liberationSerif,
    WatermarkFont.playfairDisplay,
  ];

  static List<WatermarkFont> get decorativeFonts => [
    WatermarkFont.playfairDisplay,
    WatermarkFont.oswald,
    WatermarkFont.montserrat,
  ];

  static List<WatermarkFont> get monospaceFonts => [
    WatermarkFont.sourceCodePro,
  ];
}