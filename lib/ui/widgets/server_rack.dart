import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Code-drawn placeholder server rack with blinking LEDs.
///
/// Kept behind its own widget so it can be swapped for real art later.
class ServerRack extends StatefulWidget {
  const ServerRack({
    super.key,
    this.units = 6,
    this.active = true,
    this.ledColor = AppColors.accent,
  });

  /// Number of server units (rows) drawn in the rack.
  final int units;

  /// LEDs blink while the rack is working and stay dim otherwise.
  final bool active;

  final Color ledColor;

  @override
  State<ServerRack> createState() => _ServerRackState();
}

class _ServerRackState extends State<ServerRack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ServerRack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RackPainter(
          units: widget.units,
          active: widget.active,
          ledColor: widget.ledColor,
          animation: _controller,
        ),
      ),
    );
  }
}

class _RackPainter extends CustomPainter {
  _RackPainter({
    required this.units,
    required this.active,
    required this.ledColor,
    required this.animation,
  }) : super(repaint: animation);

  final int units;
  final bool active;
  final Color ledColor;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()..color = const Color(0xFF2A3355);
    final unitPaint = Paint()..color = const Color(0xFF1B2240);
    final pad = size.width * 0.07;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(pad)),
      frame,
    );

    final unitHeight = (size.height - pad * (units + 1)) / units;
    final ledRadius = math.min(unitHeight * 0.18, size.width * 0.04);
    for (var i = 0; i < units; i++) {
      final top = pad + i * (unitHeight + pad);
      final unitRect = Rect.fromLTWH(
        pad,
        top,
        size.width - pad * 2,
        unitHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(unitRect, Radius.circular(pad * 0.4)),
        unitPaint,
      );
      for (var led = 0; led < 3; led++) {
        final color = led == 2 ? AppColors.accentAlt : ledColor;
        var on = false;
        if (active) {
          // Each LED blinks on its own phase so the rack looks busy.
          final phase = animation.value * 2 * math.pi + i * 1.3 + led * 2.1;
          on = math.sin(phase * (1 + led)) > -0.2;
        }
        canvas.drawCircle(
          Offset(
            unitRect.left + ledRadius * 2.5 + led * ledRadius * 3,
            unitRect.center.dy,
          ),
          ledRadius,
          Paint()..color = on ? color : color.withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RackPainter oldDelegate) =>
      oldDelegate.units != units ||
      oldDelegate.active != active ||
      oldDelegate.ledColor != ledColor;
}
