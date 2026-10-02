import 'package:flutter/material.dart';

import '../theme.dart';

/// Deep navy backdrop with a faint isometric floor grid and a soft glow,
/// so the screen reads as the inside of a data center.
class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.locationIndex = 0,
  });

  final Widget child;

  /// Each location gets its own color mood.
  final int locationIndex;

  static const _tints = [
    Color(0xFF111A38), // Garage: night navy.
    Color(0xFF0D2A33), // Warehouse: industrial teal.
    Color(0xFF26123D), // Campus: royal purple.
  ];

  @override
  Widget build(BuildContext context) {
    final tint = _tints[locationIndex.clamp(0, _tints.length - 1)];
    return CustomPaint(painter: _BackgroundPainter(tint), child: child);
  }
}

class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter(this.tint);

  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tint, AppColors.background, const Color(0xFF070B18)],
        ).createShader(rect),
    );
    // Soft spotlight behind the header.
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.12),
      size.width * 0.8,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.accentAlt.withValues(alpha: 0.10),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height * 0.12),
                radius: size.width * 0.8,
              ),
            ),
    );
    // Isometric floor grid: two families of lines at ±30°.
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    const spacing = 36.0;
    const slope = 0.57735; // tan 30°
    final extra = size.width * slope;
    for (var y = -extra; y < size.height + extra; y += spacing) {
      canvas
        ..drawLine(Offset(0, y), Offset(size.width, y + extra), line)
        ..drawLine(Offset(0, y + extra), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) =>
      oldDelegate.tint != tint;
}
