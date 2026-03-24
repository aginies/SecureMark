import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class WatermarkShaderPainter extends CustomPainter {
  WatermarkShaderPainter({
    required this.shader,
    required this.image,
    required this.color,
    required this.transparency,
  });

  final ui.FragmentShader shader;
  final ui.Image image;
  final Color color;
  final double transparency;

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, color.r);
    shader.setFloat(3, color.g);
    shader.setFloat(4, color.b);
    shader.setFloat(5, color.a);
    shader.setFloat(6, transparency / 100);
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant WatermarkShaderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.transparency != transparency ||
        oldDelegate.image != image;
  }
}
