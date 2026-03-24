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
        child: Padding(
          padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
          child: GestureDetector(
            onLongPress: _handleLongPress,
            child: ChoiceChip(
              label: Text(widget.label),
              avatar: Icon(
                widget.icon,
                size: 16,
                color: widget.isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selected: widget.isSelected,
              onSelected: _handleSelected,
            ),
          ),
        ),
      ),
    );
  }
}
