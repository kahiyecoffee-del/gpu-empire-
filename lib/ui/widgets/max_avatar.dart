import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

enum HairStyle { curly, short, bun, long }

/// How a code-drawn character looks.
class PersonLook {
  const PersonLook({
    required this.skin,
    required this.hair,
    required this.shirt,
    this.style = HairStyle.short,
    this.glasses = false,
  });

  final Color skin;
  final Color hair;
  final Color shirt;
  final HairStyle style;
  final bool glasses;

  /// Max, the player's CTO: curly hair, round glasses, big smile.
  static const max = PersonLook(
    skin: Color(0xFFF2C9A0),
    hair: Color(0xFF3B2416),
    shirt: AppColors.accent,
    style: HairStyle.curly,
    glasses: true,
  );

  static const _byRole = {
    'intern': PersonLook(
      skin: Color(0xFFF5D0B0),
      hair: Color(0xFF8A5A2B),
      shirt: Color(0xFFFF9F2E),
    ),
    'sysadmin': PersonLook(
      skin: Color(0xFFD9A47E),
      hair: Color(0xFF1E1A1A),
      shirt: Color(0xFF4DA3FF),
      style: HairStyle.bun,
      glasses: true,
    ),
    'network_engineer': PersonLook(
      skin: Color(0xFFF5D0B0),
      hair: Color(0xFFB8452B),
      shirt: Color(0xFFB65CFF),
      style: HairStyle.long,
    ),
    'ml_engineer': PersonLook(
      skin: Color(0xFF8D5A3B),
      hair: Color(0xFF15110F),
      shirt: Color(0xFF29E0D0),
      glasses: true,
    ),
    'chief_engineer': PersonLook(
      skin: Color(0xFFE0AC85),
      hair: Color(0xFF9AA0AE),
      shirt: Color(0xFF5B6478),
      glasses: true,
    ),
    'quantum_physicist': PersonLook(
      skin: Color(0xFFF2C9A0),
      hair: Color(0xFFE8ECF8),
      shirt: Color(0xFFFF5CC8),
      style: HairStyle.curly,
      glasses: true,
    ),
  };

  static PersonLook forRole(String role) => _byRole[role] ?? max;
}

/// Max, the player's CTO.
class MaxAvatar extends StatelessWidget {
  const MaxAvatar({super.key, this.size = 56, this.excited = false});

  final double size;

  /// Bounces gently, e.g. while a reward is waiting.
  final bool excited;

  @override
  Widget build(BuildContext context) =>
      PersonAvatar(look: PersonLook.max, size: size, excited: excited);
}

/// A round portrait of a code-drawn character that blinks now and then.
/// A placeholder until real character art arrives.
class PersonAvatar extends StatefulWidget {
  const PersonAvatar({
    super.key,
    required this.look,
    this.size = 56,
    this.excited = false,
  });

  final PersonLook look;
  final double size;
  final bool excited;

  @override
  State<PersonAvatar> createState() => _PersonAvatarState();
}

class _PersonAvatarState extends State<PersonAvatar>
    with SingleTickerProviderStateMixin {
  /// One cycle of idle animation: a blink near the end of every cycle.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 3200 + widget.look.hashCode % 900),
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
                child: CustomPaint(
                  painter: _PersonPainter(look: widget.look, blink: t > 0.95),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PersonPainter extends CustomPainter {
  _PersonPainter({required this.look, required this.blink});

  final PersonLook look;
  final bool blink;

  static const _ink = Color(0xFF1E1A1A);

  Color get _hairLight => Color.lerp(look.hair, Colors.white, 0.18)!;

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

    // Shirt and neck.
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: p(0.5, 1.08),
          width: s * 0.95,
          height: s * 0.62,
        ),
        fill..color = look.shirt,
      )
      ..drawRect(
        Rect.fromCenter(
          center: p(0.5, 0.74),
          width: s * 0.14,
          height: s * 0.12,
        ),
        fill..color = look.skin,
      );

    _hairBack(canvas, s);

    // Ears and head.
    canvas
      ..drawCircle(p(0.27, 0.48), s * 0.05, fill..color = look.skin)
      ..drawCircle(p(0.73, 0.48), s * 0.05, fill..color = look.skin)
      ..drawOval(
        Rect.fromCenter(
          center: p(0.5, 0.48),
          width: s * 0.46,
          height: s * 0.52,
        ),
        fill..color = look.skin,
      );

    _hairFront(canvas, s);

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
      ..color = look.hair == const Color(0xFFE8ECF8) ? Colors.grey : look.hair
      ..strokeWidth = s * 0.02
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(p(0.36, 0.385), p(0.44, 0.375), brow)
      ..drawLine(p(0.56, 0.375), p(0.64, 0.385), brow);

    if (look.glasses) {
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
    }

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

  void _hairBack(Canvas canvas, double s) {
    final paint = Paint()..color = look.hair;
    switch (look.style) {
      case HairStyle.curly:
        _curls(canvas, s, radius: 0.30, curl: 0.085, from: 150, to: 390);
      case HairStyle.long:
        // Hair falling to the shoulders behind the head.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(0.22 * s, 0.22 * s, 0.56 * s, 0.56 * s),
            Radius.circular(0.2 * s),
          ),
          paint,
        );
      case HairStyle.bun:
        canvas.drawCircle(Offset(0.5 * s, 0.16 * s), 0.1 * s, paint);
      case HairStyle.short:
        break;
    }
  }

  void _hairFront(Canvas canvas, double s) {
    final paint = Paint()..color = look.hair;
    switch (look.style) {
      case HairStyle.curly:
        _curls(canvas, s, radius: 0.22, curl: 0.07, from: 195, to: 345);
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
      case HairStyle.short:
      case HairStyle.bun:
      case HairStyle.long:
        // A cap of hair over the top of the head with a side parting.
        final cap = Path()
          ..moveTo(0.26 * s, 0.46 * s)
          ..quadraticBezierTo(0.24 * s, 0.2 * s, 0.5 * s, 0.19 * s)
          ..quadraticBezierTo(0.76 * s, 0.2 * s, 0.74 * s, 0.46 * s)
          ..quadraticBezierTo(0.7 * s, 0.32 * s, 0.56 * s, 0.31 * s)
          ..quadraticBezierTo(0.42 * s, 0.36 * s, 0.3 * s, 0.33 * s)
          ..close();
        canvas.drawPath(cap, paint);
    }
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
    Color? color,
    double step = 17,
  }) {
    final paint = Paint()..color = color ?? look.hair;
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
  bool shouldRepaint(_PersonPainter oldDelegate) =>
      oldDelegate.blink != blink || oldDelegate.look != look;
}
