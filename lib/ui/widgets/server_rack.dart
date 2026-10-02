import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Code-drawn placeholder server rack with blinking LEDs.
///
/// Kept behind its own widget so it can be swapped for real art later.
class ServerRack extends StatefulWidget {
  const ServerRack({super.key, this.units = 6});

  /// Number of server units (rows) drawn in the rack.
  final int units;

  @override
  State<ServerRack> createState() => _ServerRackState();
}

class _ServerRackState extends State<ServerRack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RackPainter(units: widget.units, animation: _controller),
      ),
    );
  }
}

class _RackPainter extends CustomPainter {
  _RackPainter({required this.units, required this.animation})
    : super(repaint: animation);

  final int units;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()..color = const Color(0xFF2A3355);
    final unitPaint = Paint()..color = const Color(0xFF1B2240);
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, frame);

    const pad = 8.0;
    final unitHeight = (size.height - pad * (units + 1)) / units;
    for (var i = 0; i < units; i++) {
      final top = pad + i * (unitHeight + pad);
      final unitRect = Rect.fromLTWH(
        pad,
        top,
        size.width - pad * 2,
        unitHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(unitRect, const Radius.circular(3)),
        unitPaint,
      );
      for (var led = 0; led < 3; led++) {
        // Each LED blinks on its own phase so the rack looks busy.
        final phase = (animation.value * 2 * math.pi) + i * 1.3 + led * 2.1;
        final on = math.sin(phase * (1 + led)) > -0.2;
        final color = led == 2 ? AppColors.accentAlt : AppColors.accent;
        canvas.drawCircle(
          Offset(unitRect.left + 10 + led * 9, unitRect.center.dy),
          3,
          Paint()..color = on ? color : color.withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RackPainter oldDelegate) => oldDelegate.units != units;
}
