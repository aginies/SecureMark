import 'package:flutter/material.dart';

import '../utils/color_utils.dart';

/// A gradient-filled button with press animation.
class GradientButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final List<Color> gradientColors;
  final bool enabled;

  const GradientButton({
    super.key,
    required this.child,
    this.onTap,
    required this.gradientColors,
    this.enabled = true,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onPointerCancel:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: widget.enabled
              ? LinearGradient(
                  colors: widget.gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color:
              widget.enabled ? null : theme.colorScheme.surfaceContainerHighest,
          boxShadow: (widget.enabled && !_isPressed)
              ? [
                  BoxShadow(
                    color: ColorUtils.getAdaptiveShadowColor(theme,
                        color: widget.gradientColors.first, alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            borderRadius: BorderRadius.circular(16),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class PushDownWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const PushDownWrapper({super.key, required this.child, this.enabled = true});

  @override
  State<PushDownWrapper> createState() => _PushDownWrapperState();
}

class _PushDownWrapperState extends State<PushDownWrapper> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _isPressed = true) : null,
      onPointerUp:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      onPointerCancel:
          widget.enabled ? (_) => setState(() => _isPressed = false) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: (widget.enabled && !_isPressed)
              ? [
                  BoxShadow(
                    color:
                        ColorUtils.getAdaptiveShadowColor(theme, alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ]
              : [],
        ),
        child: widget.child,
      ),
    );
  }
}
