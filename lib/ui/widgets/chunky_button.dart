import 'package:flutter/material.dart';

import '../theme.dart';

/// A "physical" 3D button: colored face over a darker base that sinks when
/// pressed. Disabled buttons go flat and grey.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = AppColors.accent,
    this.foreground = AppColors.background,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    this.radius = 14,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final Color foreground;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  static const _depth = 4.0;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final face = enabled ? widget.color : const Color(0xFF2A3150);
    final base = enabled
        ? HSLColor.fromColor(face)
              .withLightness(
                (HSLColor.fromColor(face).lightness - 0.18).clamp(0.0, 1.0),
              )
              .toColor()
        : const Color(0xFF1B2140);
    final offset = _down ? _depth : 0.0;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: Padding(
        padding: EdgeInsets.only(top: offset),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 60),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
          padding: EdgeInsets.only(bottom: _depth - offset),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(Colors.white.withValues(alpha: 0.18), face),
                  face,
                ],
              ),
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: enabled ? widget.foreground : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: enabled ? widget.foreground : AppColors.textSecondary,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
