import 'package:flutter/material.dart';

/// Paints the draggable crosshair used by the logo position picker.
class XYPadPainter extends CustomPainter {
  final double x;
  final double y;
  final Color color;

  XYPadPainter({required this.x, required this.y, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    // Vertical line
    canvas.drawLine(
        Offset(x * size.width, 0), Offset(x * size.width, size.height), paint);
    // Horizontal line
    canvas.drawLine(
        Offset(0, y * size.height), Offset(size.width, y * size.height), paint);
  }

  @override
  bool shouldRepaint(covariant XYPadPainter oldDelegate) =>
      oldDelegate.x != x || oldDelegate.y != y || oldDelegate.color != color;
}
