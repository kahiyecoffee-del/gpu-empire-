import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../line_style.dart';

/// An isometric (2.5D) server rack drawn in code: shaded faces, glowing
/// LEDs, a spinning side fan and a soft floor shadow. Shows 1–3 racks as the
/// line grows.
class IsoRack extends StatefulWidget {
  const IsoRack({
    super.key,
    required this.style,
    this.racks = 1,
    this.active = false,
    this.locked = false,
  });

  final LineStyle style;

  /// Number of racks in the row (1–3).
  final int racks;

  /// LEDs blink and fans spin while a job runs.
  final bool active;

  /// Draws a dim, desaturated silhouette.
  final bool locked;

  @override
  State<IsoRack> createState() => _IsoRackState();
}

class _IsoRackState extends State<IsoRack> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(IsoRack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.active && !widget.locked;
    if (animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!animate && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _IsoRackPainter(
          style: widget.style,
          racks: widget.racks.clamp(1, 3),
          active: widget.active && !widget.locked,
          locked: widget.locked,
          clock: _clock,
        ),
      ),
    );
  }
}

class _IsoRackPainter extends CustomPainter {
  _IsoRackPainter({
    required this.style,
    required this.racks,
    required this.active,
    required this.locked,
    required this.clock,
  }) : super(repaint: clock);

  final LineStyle style;
  final int racks;
  final bool active;
  final bool locked;
  final Animation<double> clock;

  static const _cos30 = 0.8660254;

  Color _shade(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    // One rack is W wide, D deep and H tall in iso units; the row of racks
    // is scaled to fit the box.
    const w = 1.0, d = 0.75, h = 1.55;
    const gap = 0.12;
    final rowWidth = racks * w + (racks - 1) * gap;
    final spanX = (rowWidth + d) * _cos30;
    final spanY = (rowWidth + d) * 0.5 + h;
    final unit = math.min(size.width / spanX, size.height / (spanY + 0.25));
    final origin = Offset(
      (size.width - spanX * unit) / 2 + d * _cos30 * unit,
      (size.height - (spanY + 0.25) * unit) / 2,
    );

    Offset iso(double x, double y, double z) => Offset(
      origin.dx + (x - y) * _cos30 * unit,
      origin.dy + ((x + y) * 0.5 + z) * unit,
    );

    // Larger x is nearer the viewer, so draw left to right.
    for (var i = 0; i < racks; i++) {
      _rack(canvas, iso, unit, i * (w + gap), w, d, h, i);
    }
  }

  void _rack(
    Canvas canvas,
    Offset Function(double, double, double) iso,
    double unit,
    double x0,
    double w,
    double d,
    double h,
    int index,
  ) {
    // Locked racks keep a hint of their color so players see what is next.
    final body = locked
        ? Color.lerp(style.body, const Color(0xFF39415E), 0.65)!
        : style.body;
    final top = _shade(body, 0.16);
    final front = body;
    final side = _shade(body, -0.12);

    // Floor shadow.
    final shadowCenter = iso(x0 + w / 2, d / 2, h + 0.05);
    canvas.drawOval(
      Rect.fromCenter(
        center: shadowCenter,
        width: (w + d) * _cos30 * unit * 1.25,
        height: (w + d) * 0.5 * unit * 0.9,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.12),
    );

    Path quad(Offset a, Offset b, Offset c, Offset e) => Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(c.dx, c.dy)
      ..lineTo(e.dx, e.dy)
      ..close();

    // Corners: front face is the y = d plane, side face the x = x0 + w plane.
    final t0 = iso(x0, 0, 0);
    final t1 = iso(x0 + w, 0, 0);
    final t2 = iso(x0 + w, d, 0);
    final t3 = iso(x0, d, 0);
    final b1 = iso(x0 + w, 0, h);
    final b2 = iso(x0 + w, d, h);
    final b3 = iso(x0, d, h);

    final frontPath = quad(t3, t2, b2, b3);
    final sidePath = quad(t2, t1, b1, b2);
    final topPath = quad(t0, t1, t2, t3);

    canvas
      ..drawPath(
        frontPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_shade(front, 0.04), _shade(front, -0.06)],
          ).createShader(frontPath.getBounds()),
      )
      ..drawPath(sidePath, Paint()..color = side)
      ..drawPath(topPath, Paint()..color = top);

    // Edge highlights give the box a crisp, polished look.
    final edge = Paint()
      ..color = Colors.white.withValues(alpha: locked ? 0.06 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.02;
    canvas
      ..drawLine(t3, t2, edge)
      ..drawLine(t2, t1, edge)
      ..drawLine(t2, b2, edge);

    // Top vents.
    final vent = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..strokeWidth = unit * 0.025;
    for (var k = 1; k <= 3; k++) {
      final y = d * k / 4;
      canvas.drawLine(iso(x0 + w * 0.2, y, 0), iso(x0 + w * 0.8, y, 0), vent);
    }

    // Server units on the front face.
    const units = 5;
    final slot = Paint()..color = Colors.black.withValues(alpha: 0.35);
    for (var u = 0; u < units; u++) {
      final z0 = h * (0.1 + u * 0.165);
      final z1 = z0 + h * 0.12;
      canvas.drawPath(
        quad(
          iso(x0 + w * 0.08, d, z0),
          iso(x0 + w * 0.92, d, z0),
          iso(x0 + w * 0.92, d, z1),
          iso(x0 + w * 0.08, d, z1),
        ),
        slot,
      );
      if (locked) continue;
      for (var led = 0; led < 3; led++) {
        final phase =
            clock.value * 2 * math.pi * (1 + led) + u * 1.7 + led * 2.3 + index;
        final on = active ? math.sin(phase) > -0.3 : (u + led).isEven;
        final color = led == 2 ? Colors.white : style.led;
        final center = iso(x0 + w * (0.18 + led * 0.11), d, (z0 + z1) / 2);
        if (on) {
          canvas.drawCircle(
            center,
            unit * 0.07,
            Paint()
              ..color = color.withValues(alpha: active ? 0.55 : 0.25)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, unit * 0.06),
          );
        }
        canvas.drawCircle(
          center,
          unit * 0.03,
          Paint()..color = on ? color : color.withValues(alpha: 0.18),
        );
      }
    }

    // Spinning fan on the side face, drawn in the side plane's coordinates.
    if (!locked) {
      final fanCenter = iso(x0 + w, d / 2, h * 0.32);
      final axisY = iso(x0 + w, d / 2 + 0.2, h * 0.32) - fanCenter;
      final axisZ = iso(x0 + w, d / 2, h * 0.32 + 0.2) - fanCenter;
      canvas
        ..save()
        ..transform(
          Float64List.fromList([
            axisY.dx / 0.2, axisY.dy / 0.2, 0, 0, //
            axisZ.dx / 0.2, axisZ.dy / 0.2, 0, 0, //
            0, 0, 1, 0, //
            fanCenter.dx, fanCenter.dy, 0, 1, //
          ]),
        );
      const r = 0.22;
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      final blade = Paint()..color = _shade(side, 0.2);
      final spin = active ? clock.value * 2 * math.pi * 3 : 0.4;
      for (var b = 0; b < 4; b++) {
        final a = spin + b * math.pi / 2;
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(math.cos(a) * r * 0.9, math.sin(a) * r * 0.9)
            ..lineTo(math.cos(a + 0.6) * r * 0.9, math.sin(a + 0.6) * r * 0.9)
            ..close(),
          blade,
        );
      }
      canvas
        ..drawCircle(Offset.zero, r * 0.18, Paint()..color = _shade(side, 0.3))
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_IsoRackPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.racks != racks ||
      oldDelegate.active != active ||
      oldDelegate.locked != locked;
}
