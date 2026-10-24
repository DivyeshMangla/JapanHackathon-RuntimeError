import 'package:flutter/material.dart';

/// Accent-filled call to action with the 1px tactile press from design.md.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _TactilePress(
      enabled: onPressed != null,
      child: icon == null
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
    );
  }
}

/// Outline (ghost) variant.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return _TactilePress(
      enabled: onPressed != null,
      child: icon == null
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(label),
            ),
    );
  }
}

class _TactilePress extends StatefulWidget {
  const _TactilePress({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_TactilePress> createState() => _TactilePressState();
}

class _TactilePressState extends State<_TactilePress> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.enabled && value != _pressed) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 120),
        scale: _pressed ? 0.98 : 1,
        child: widget.child,
      ),
    );
  }
}
