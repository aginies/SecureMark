import 'package:flutter/material.dart';

/// Clips a preview horizontally or vertically for before/after comparison.
class ComparisonClipper extends CustomClipper<Rect> {
  final double value;
  final bool
      isVertical; // true for vertical line (left-right drag), false for horizontal line (up-down drag)

  ComparisonClipper(this.value, {this.isVertical = true});

  @override
  Rect getClip(Size size) {
    if (isVertical) {
      return Rect.fromLTRB(0, 0, size.width * value, size.height);
    } else {
      return Rect.fromLTRB(0, 0, size.width, size.height * value);
    }
  }

  @override
  bool shouldReclip(ComparisonClipper oldClipper) =>
      oldClipper.value != value || oldClipper.isVertical != isVertical;
}
