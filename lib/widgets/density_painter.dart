import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paints the watermark density preview grid and "SecureMark" preview text.
class DensityPainter extends CustomPainter {
  final double density;
  final Color color;
  final bool isPreview;
  final bool useRandomColor;

  DensityPainter({
    required this.density,
    required this.color,
    this.isPreview = false,
    this.useRandomColor = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final List<Color> randomPalette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
    ];
    final math.Random random =
        math.Random(42); // Seed for consistent randomness per frame

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Map density (10-90) to grid count (2-8)
    final count = ((density / 100) * 7 + 2).round();
    final stepX = size.width / (count + 1);
    final stepY = size.height / (count + 1);

    for (int i = 1; i <= count; i++) {
      for (int j = 1; j <= count; j++) {
        if (useRandomColor) {
          paint.color = randomPalette[random.nextInt(randomPalette.length)]
              .withValues(alpha: 0.6);
        }
        canvas.drawCircle(Offset(i * stepX, j * stepY), 3.0, paint);
      }
    }

    if (isPreview) {
      InlineSpan textSpan;
      if (useRandomColor) {
        // Each letter with a random color
        final String text = 'SecureMark';
        textSpan = TextSpan(
          children: text.split('').map((char) {
            return TextSpan(
              text: char,
              style: TextStyle(
                color: randomPalette[random.nextInt(randomPalette.length)],
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            );
          }).toList(),
        );
      } else {
        textSpan = TextSpan(
          text: 'SecureMark',
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        );
      }

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2,
            (size.height - textPainter.height) / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant DensityPainter oldDelegate) {
    return oldDelegate.density != density ||
        oldDelegate.color != color ||
        oldDelegate.isPreview != isPreview ||
        oldDelegate.useRandomColor != useRandomColor;
  }
}
