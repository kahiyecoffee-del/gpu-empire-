import 'package:flutter/material.dart';

import '../theme.dart';

/// Rounded panel with a subtle gradient, a light top edge and a drop shadow.
/// [tint] colors the gradient, e.g. with a line's accent.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.tint,
    this.highlight,
    this.padding = const EdgeInsets.all(12),
    this.radius = 20,
  });

  final Widget child;
  final Color? tint;

  /// Glowing border color, e.g. when something needs attention.
  final Color? highlight;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final base = tint ?? AppColors.accentAlt;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(base.withValues(alpha: 0.16), AppColors.surface),
            Color.alphaBlend(
              base.withValues(alpha: 0.04),
              const Color(0xFF0E1428),
            ),
          ],
        ),
        border: Border.all(
          color: highlight ?? Colors.white.withValues(alpha: 0.08),
          width: highlight == null ? 1 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          if (highlight != null)
            BoxShadow(
              color: highlight!.withValues(alpha: 0.35),
              blurRadius: 16,
            ),
        ],
      ),
      child: child,
    );
  }
}
