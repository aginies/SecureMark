import 'package:flutter/material.dart';

import 'gradient_button.dart';

/// A tappable tile used in color pickers, with circle/square shape support.
class ColorTile extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool processing;
  final bool isCircle;

  const ColorTile({
    super.key,
    required this.child,
    required this.onTap,
    required this.processing,
    this.isCircle = true,
  });

  @override
  State<ColorTile> createState() => _ColorTileState();
}

class _ColorTileState extends State<ColorTile> {
  @override
  Widget build(BuildContext context) {
    return PushDownWrapper(
      enabled: !widget.processing,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.processing ? null : widget.onTap,
          borderRadius: BorderRadius.circular(widget.isCircle ? 999 : 4),
          child: widget.child,
        ),
      ),
    );
  }
}
