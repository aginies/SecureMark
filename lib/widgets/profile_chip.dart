import 'package:flutter/material.dart';
import '../models/settings_profile.dart';

class ProfileChip extends StatefulWidget {
  final SettingsProfile profile;
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onSelected;
  final VoidCallback onLongPress;

  const ProfileChip({
    super.key,
    required this.profile,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDisabled,
    required this.onSelected,
    required this.onLongPress,
  });

  @override
  State<ProfileChip> createState() => _ProfileChipState();
}

class _ProfileChipState extends State<ProfileChip>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  late AnimationController _tapController;
  late Animation<double> _tapAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _tapAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _handleLongPress() {
    if (widget.profile == SettingsProfile.none || widget.isDisabled) return;
    _pulseController.forward(from: 0.0);
    widget.onLongPress();
  }

  void _handleSelected(bool selected) {
    if (widget.isDisabled) return;
    _tapController.forward(from: 0.0);
    widget.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ScaleTransition(
      scale: _pulseAnimation,
      child: ScaleTransition(
        scale: _tapAnimation,
        child: GestureDetector(
          onTap: () => _handleSelected(true),
          onLongPress: _handleLongPress,
          child: Container(
            margin: const EdgeInsets.only(right: 8.0, bottom: 6.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.25)
                      : theme.colorScheme.shadow.withValues(alpha: 0.1),
                  blurRadius: widget.isSelected ? 8 : 4,
                  offset: Offset(0, widget.isSelected ? 4 : 2),
                ),
              ],
            ),
            child: RawChip(
              label: Text(widget.label),
              avatar: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: widget.isSelected
                      ? [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ]
                      : [
                          theme.colorScheme.onSurfaceVariant,
                          theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              selected: widget.isSelected,
              showCheckmark: false,
              side: BorderSide(
                color: widget.isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: widget.isSelected ? 2.0 : 1.0,
              ),
              backgroundColor: theme.colorScheme.surface,
              selectedColor:
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: widget.isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight:
                    widget.isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
