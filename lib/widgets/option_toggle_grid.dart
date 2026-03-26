import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/watermark_option.dart';

/// Grid of toggleable option icons with visual feedback
class OptionToggleGrid extends StatelessWidget {
  final List<WatermarkOption> options;
  final EdgeInsets padding;
  final double iconSize;
  final double spacing;

  const OptionToggleGrid({
    super.key,
    required this.options,
    this.padding = const EdgeInsets.all(8.0),
    this.iconSize = 48.0,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate width for 4 icons per row
          final availableWidth = constraints.maxWidth - (padding.horizontal);
          final totalSpacing = spacing * 3; // 3 gaps between 4 icons
          final iconWidth = (availableWidth - totalSpacing) / 4;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            alignment: WrapAlignment.start,
            children: options.map((option) {
              return SizedBox(
                width: iconWidth,
                child: _buildOptionTile(context, option),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildOptionTile(BuildContext context, WatermarkOption option) {
    return _OptionTile(
      option: option,
      iconSize: iconSize,
    );
  }
}

/// Individual option tile with toggle and configuration
class _OptionTile extends StatefulWidget {
  final WatermarkOption option;
  final double iconSize;

  const _OptionTile({
    required this.option,
    required this.iconSize,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    final l10n = AppLocalizations.of(context)!;
    // Single tap: Show info
    final parts = <String>[widget.option.label];

    if (!widget.option.isAvailable && widget.option.unavailableReason != null) {
      parts.add(widget.option.unavailableReason!);
    } else {
      if (widget.option.subtitle != null) {
        parts.add(widget.option.subtitle!);
      }
      // Only show status if it's toggleable
      if (widget.option.onToggle != null) {
        parts.add(
            widget.option.isEnabled ? 'Status: Enabled' : 'Status: Disabled');
        parts.add('Double-tap to toggle');
      }
      if (widget.option.onConfigure != null) {
        parts.add(l10n.longPressToConfigure);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(parts.join('\n')),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDoubleTap() {
    if (!widget.option.isAvailable) {
      // Show unavailable reason
      if (widget.option.unavailableReason != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.option.unavailableReason!),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    // Only toggle if onToggle is available
    if (widget.option.onToggle == null) {
      // If not toggleable, just show info
      _handleTap();
      return;
    }

    // Toggle with haptic feedback
    HapticFeedback.lightImpact();
    _scaleController.forward().then((_) => _scaleController.reverse());

    widget.option.onToggle!.call();

    // Show confirmation snackbar
    final message = widget.option.isEnabled
        ? '${widget.option.label} disabled'
        : '${widget.option.label} enabled';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        width: 250,
      ),
    );
  }

  void _handleLongPress() {
    if (widget.option.onConfigure != null) {
      HapticFeedback.mediumImpact();
      widget.option.onConfigure!.call();
    } else {
      // If no configure dialog, show info
      _handleTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.option.isEnabled;
    final isAvailable = widget.option.isAvailable;

    // Color logic
    final Color iconColor;
    final Color backgroundColor;
    final double opacity;

    if (!isAvailable) {
      // Locked/unavailable
      iconColor = Colors.grey.shade400;
      backgroundColor = Colors.grey.shade200;
      opacity = 0.5;
    } else if (isEnabled) {
      // Enabled
      iconColor = widget.option.enabledColor;
      backgroundColor = widget.option.enabledColor.withValues(alpha: 0.15);
      opacity = 1.0;
    } else {
      // Available but disabled - subtle hint of natural color
      iconColor = widget.option.enabledColor.withValues(alpha: 0.2);
      backgroundColor = widget.option.enabledColor.withValues(alpha: 0.02);
      opacity = 1.0;
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Tooltip(
        message: _buildTooltipMessage(),
        triggerMode: TooltipTriggerMode.tap,
        child: GestureDetector(
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onLongPressStart: (_) => _handleLongPress(),
          child: Container(
            width: widget.iconSize + 24,
            height: widget.iconSize + 24,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEnabled
                    ? widget.option.enabledColor.withValues(alpha: 0.4)
                    : (isAvailable
                        ? widget.option.enabledColor.withValues(alpha: 0.2)
                        : Colors.grey.shade300),
                width: isEnabled ? 2 : 1,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color:
                            widget.option.enabledColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: opacity,
                  child: Icon(
                    widget.option.icon,
                    color: iconColor,
                    size: widget.iconSize * 0.9,
                  ),
                ),
                // Lock overlay for unavailable
                if (!isAvailable)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(
                        Icons.lock_outline,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                // Checkmark for enabled (only if toggleable)
                if (isEnabled && isAvailable && widget.option.onToggle != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: widget.option.enabledColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                // Info badge for info-only options
                if (isEnabled && isAvailable && widget.option.onToggle == null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: widget.option.enabledColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildTooltipMessage() {
    final l10n = AppLocalizations.of(context)!;
    final parts = [widget.option.label];

    if (!widget.option.isAvailable && widget.option.unavailableReason != null) {
      parts.add(widget.option.unavailableReason!);
    } else {
      if (widget.option.subtitle != null) {
        parts.add(widget.option.subtitle!);
      }
      // Only mention toggle if it's available
      if (widget.option.onToggle != null) {
        parts.add('Tap: info • Double-tap: toggle');
      } else {
        parts.add('Tap: info');
      }
      if (widget.option.onConfigure != null) {
        parts.add(l10n.longPressConfigure);
      }
    }

    return parts.join('\n');
  }
}
