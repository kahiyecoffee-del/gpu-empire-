import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Max, the player's CTO: curly hair, round glasses, big smile. Drawn in
/// code as a placeholder until real character art arrives.
class MaxAvatar extends StatefulWidget {
  const MaxAvatar({super.key, this.size = 56, this.excited = false});

  final double size;

  /// Bounces gently, e.g. while a reward is waiting.
  final bool excited;

  @override
  State<MaxAvatar> createState() => _MaxAvatarState();
}

class _MaxAvatarState extends State<MaxAvatar>
    with SingleTickerProviderStateMixin {
  /// One cycle of idle animation: a blink near the end of every cycle.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value;
            final bounce = widget.excited
                ? -math.sin(t * 2 * math.pi * 4).abs() * widget.size * 0.05
                : 0.0;
            return Transform.translate(
              offset: Offset(0, bounce),
              child: SizedBox.square(
                dimension: widget.size,
                child: CustomPaint(painter: _MaxPainter(blink: t > 0.95)),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MaxPainter extends CustomPainter {
  _MaxPainter({required this.blink});

  final bool blink;

  static const _skin = Color(0xFFF2C9A0);
  static const _hair = Color(0xFF3B2416);
  static const _hairLight = Color(0xFF5C3A24);
  static const _ink = Color(0xFF1E1A1A);
  static const _hoodie = AppColors.accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset p(double x, double y) => Offset(x * s, y * s);
    final fill = Paint()..isAntiAlias = true;

    // Badge background, clipped to a circle.
    canvas
      ..save()
      ..clipPath(Path()..addOval(Offset.zero & size));
    canvas.drawRect(Offset.zero & size, fill..color = const Color(0xFF26335C));

    // Hoodie and neck.
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: p(0.5, 1.08),
          width: s * 0.95,
          height: s * 0.62,
        ),
        fill..color = _hoodie,
      )
      ..drawRect(
        Rect.fromCenter(
          center: p(0.5, 0.74),
          width: s * 0.14,
          height: s * 0.12,
        ),
        fill..color = _skin,
      );

    // Back layer of curls, behind the head.
    _curls(
      canvas,
      s,
      radius: 0.30,
      curl: 0.085,
      from: 150,
      to: 390,
      color: _hair,
    );

    // Ears and head.
    canvas
      ..drawCircle(p(0.27, 0.48), s * 0.05, fill..color = _skin)
      ..drawCircle(p(0.73, 0.48), s * 0.05, fill..color = _skin)
      ..drawOval(
        Rect.fromCenter(
          center: p(0.5, 0.48),
          width: s * 0.46,
          height: s * 0.52,
        ),
        fill..color = _skin,
      );

    // Front curls: a fringe over the forehead.
    _curls(
      canvas,
      s,
      radius: 0.22,
      curl: 0.07,
      from: 195,
      to: 345,
      color: _hair,
    );
    _curls(
      canvas,
      s,
      radius: 0.24,
      curl: 0.03,
      from: 205,
      to: 335,
      color: _hairLight,
      step: 26,
    );

    // Cheeks.
    final blush = Paint()..color = const Color(0x33FF6B8A);
    canvas
      ..drawCircle(p(0.36, 0.58), s * 0.045, blush)
      ..drawCircle(p(0.64, 0.58), s * 0.045, blush);

    // Eyes (or a blink).
    final eye = Paint()
      ..color = _ink
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;
    for (final x in [0.41, 0.59]) {
      if (blink) {
        canvas.drawLine(p(x - 0.025, 0.49), p(x + 0.025, 0.49), eye);
      } else {
        canvas.drawCircle(p(x, 0.49), s * 0.022, eye);
      }
    }

    // Eyebrows.
    final brow = Paint()
      ..color = _hair
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(p(0.36, 0.385), p(0.44, 0.375), brow)
      ..drawLine(p(0.56, 0.375), p(0.64, 0.385), brow);

    // Round glasses with a bridge and temples.
    final frame = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022;
    final lens = Paint()..color = const Color(0x22FFFFFF);
    for (final x in [0.41, 0.59]) {
      canvas
        ..drawCircle(p(x, 0.49), s * 0.075, lens)
        ..drawCircle(p(x, 0.49), s * 0.075, frame);
    }
    canvas
      ..drawLine(p(0.485, 0.485), p(0.515, 0.485), frame)
      ..drawLine(p(0.335, 0.48), p(0.28, 0.46), frame)
      ..drawLine(p(0.665, 0.48), p(0.72, 0.46), frame);

    // Smile.
    final mouth = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(
        Rect.fromCenter(center: p(0.5, 0.6), width: s * 0.16, height: s * 0.1),
        0.15 * math.pi,
        0.7 * math.pi,
        false,
        mouth,
      )
      ..restore();
  }

  /// Draws circles along an arc around the head (angles in degrees, 0 = right,
  /// 270 = top) to build curly hair.
  void _curls(
    Canvas canvas,
    double s, {
    required double radius,
    required double curl,
    required double from,
    required double to,
    required Color color,
    double step = 17,
  }) {
    final paint = Paint()..color = color;
    const center = Offset(0.5, 0.42);
    var i = 0;
    for (var a = from; a <= to; a += step) {
      final rad = a * math.pi / 180;
      // Alternate sizes so the curls look natural.
      final r = curl * (i.isEven ? 1.0 : 0.85);
      canvas.drawCircle(
        Offset(
          (center.dx + math.cos(rad) * radius) * s,
          (center.dy + math.sin(rad) * radius * 0.95) * s,
        ),
        r * s,
        paint,
      );
      i++;
    }
  }

  @override
  bool shouldRepaint(_MaxPainter oldDelegate) => oldDelegate.blink != blink;
}
