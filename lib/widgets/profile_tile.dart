import 'package:flutter/material.dart';

import 'gradient_button.dart';
import '../models/settings_profile.dart';
import '../utils/color_utils.dart';

/// A selectable profile tile shown in the horizontal profile selector.
class ProfileTile extends StatefulWidget {
  final SettingsProfile profile;
  final String label;
  final IconData icon;
  final bool isSelected;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool processing;

  const ProfileTile({
    super.key,
    required this.profile,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
    required this.processing,
  });

  @override
  State<ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<ProfileTile> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.theme.colorScheme;

    return PushDownWrapper(
      enabled: !widget.processing,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.processing ? null : widget.onTap,
          onLongPress: widget.processing ? null : widget.onLongPress,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.7)
                  : colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: widget.isSelected
                  ? [
                      BoxShadow(
                        color: ColorUtils.getAdaptiveShadowColor(widget.theme,
                            color: colorScheme.primary),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                  : [],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: widget.isSelected
                            ? [colorScheme.primary, colorScheme.secondary]
                            : [
                                colorScheme.onSurfaceVariant,
                                colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.7)
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: widget.isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
