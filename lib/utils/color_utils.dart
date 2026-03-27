import 'dart:math';
import 'package:flutter/material.dart';

/// Color conversion utilities for watermark generation
class ColorUtils {
  /// Returns a shadow color that is visible in both light and dark themes.
  ///
  /// In dark mode, it returns white with a very low opacity.
  /// In light mode, it returns the provided [color] (defaulting to theme shadow) with [alpha].
  static Color getAdaptiveShadowColor(ThemeData theme,
      {Color? color, double alpha = 0.2}) {
    if (theme.brightness == Brightness.dark) {
      return Colors.white.withValues(alpha: 0.12);
    }
    return (color ?? theme.colorScheme.shadow).withValues(alpha: alpha);
  }

  // ITU-R BT.601 standard coefficients for RGB ↔ YCbCr conversion

  /// RGB to Y (luminance) conversion coefficients
  static const double rgbToYRed = 0.299;
  static const double rgbToYGreen = 0.587;
  static const double rgbToYBlue = 0.114;

  /// RGB to Cb (blue-difference chroma) conversion coefficients
  static const double rgbToCbRed = -0.1687;
  static const double rgbToCbGreen = -0.3313;
  static const double rgbToCbBlue = 0.5;

  /// RGB to Cr (red-difference chroma) conversion coefficients
  static const double rgbToCrRed = 0.5;
  static const double rgbToCrGreen = -0.4187;
  static const double rgbToCrBlue = -0.0813;

  /// YCbCr to RGB conversion coefficients
  static const double yCbCrToRgbCr = 1.402;
  static const double yCbCrToRgbCbGreen = -0.344136;
  static const double yCbCrToRgbCrGreen = -0.714136;
  static const double yCbCrToRgbCb = 1.772;

  /// Chroma offset for unsigned representation (used in Cb and Cr)
  static const double chromaOffset = 128.0;

  /// Converts HSV color space to RGB color space
  ///
  /// If [hue] is null, generates a random hue value (0-360).
  /// Returns RGB values as integers in range 0-255.
  ///
  /// Parameters:
  /// - [hue]: Hue value (0-360 degrees), null for random
  /// - [saturation]: Saturation (0.0-1.0), defaults to 0.8 (80%)
  /// - [value]: Value/brightness (0.0-1.0), defaults to 0.95 (95%)
  /// - [random]: Random instance for hue generation, creates new if null
  static (int r, int g, int b) hsvToRgb({
    double? hue,
    double saturation = 0.8,
    double value = 0.95,
    Random? random,
  }) {
    // Generate random hue if not provided
    final h = hue ?? (random ?? Random()).nextDouble() * 360;

    // HSV to RGB conversion using standard algorithm
    final c = value * saturation; // Chroma
    final x = c * (1 - (((h / 60) % 2) - 1).abs());
    final m = value - c;

    // Determine RGB' values based on hue sector (6 sectors of 60° each)
    double rPrime, gPrime, bPrime;
    if (h < 60) {
      rPrime = c;
      gPrime = x;
      bPrime = 0;
    } else if (h < 120) {
      rPrime = x;
      gPrime = c;
      bPrime = 0;
    } else if (h < 180) {
      rPrime = 0;
      gPrime = c;
      bPrime = x;
    } else if (h < 240) {
      rPrime = 0;
      gPrime = x;
      bPrime = c;
    } else if (h < 300) {
      rPrime = x;
      gPrime = 0;
      bPrime = c;
    } else {
      rPrime = c;
      gPrime = 0;
      bPrime = x;
    }

    // Add m to match value, convert to 0-255 range
    final r = ((rPrime + m) * 255).round();
    final g = ((gPrime + m) * 255).round();
    final b = ((bPrime + m) * 255).round();

    return (r, g, b);
  }
}
