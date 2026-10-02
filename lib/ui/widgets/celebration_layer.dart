import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_events.dart';

enum CelebrationSize { small, big }

/// Asks the [CelebrationLayer] for confetti outside game events (e.g. when
/// the wheel stops).
final celebrationProvider = Provider<CelebrationBus>((ref) {
  final bus = CelebrationBus();
  ref.onDispose(bus.close);
  return bus;
});

class CelebrationBus {
  final _controller = StreamController<CelebrationSize>.broadcast(sync: true);

  Stream<CelebrationSize> get stream => _controller.stream;

  void celebrate(CelebrationSize size) {
    if (!_controller.isClosed) _controller.add(size);
  }

  void close() => unawaited(_controller.close());
}

/// Full-screen confetti above everything (sheets and dialogs included).
/// Never takes touches.
class CelebrationLayer extends ConsumerStatefulWidget {
  const CelebrationLayer({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends ConsumerState<CelebrationLayer>
    with TickerProviderStateMixin {
  final _random = math.Random();
  final List<_Burst> _bursts = [];
  final List<StreamSubscription<Object>> _subs = [];

  @override
  void initState() {
    super.initState();
    _subs
      ..add(ref.read(gameEventsProvider).stream.listen(_onEvent))
      ..add(ref.read(celebrationProvider).stream.listen(_start));
  }

  void _onEvent(GameEvent e) {
    switch (e.type) {
      case GameEventType.ipo || GameEventType.purchase || GameEventType.move:
        _start(CelebrationSize.big);
      case GameEventType.questClaim:
        _start(CelebrationSize.small);
      default:
        break;
    }
  }

  void _start(CelebrationSize size) {
    if (!mounted) return;
    final big = size == CelebrationSize.big;
    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: big ? 3000 : 1800),
    );
    final burst = _Burst(
      controller,
      List.generate(big ? 140 : 50, (_) => _Particle.random(_random, big)),
    );
    setState(() => _bursts.add(burst));
    controller.forward().whenComplete(() {
      controller.dispose();
      if (mounted) setState(() => _bursts.remove(burst));
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    for (final b in _bursts) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        for (final b in _bursts)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _ConfettiPainter(b)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Burst {
  _Burst(this.controller, this.particles);

  final AnimationController controller;
  final List<_Particle> particles;
}

const _colors = [
  Color(0xFF3DDC97),
  Color(0xFFFFC44D),
  Color(0xFFFF5CC8),
  Color(0xFF5CC8FF),
  Color(0xFFB65CFF),
  Color(0xFFFF9F2E),
];

/// One confetti piece. Positions are fractions of the screen; [big] bursts
/// rain from the top, small ones pop out of the middle.
class _Particle {
  _Particle(this.x, this.y, this.vx, this.vy, this.spin, this.color, this.size);

  factory _Particle.random(math.Random r, bool big) {
    final color = _colors[r.nextInt(_colors.length)];
    if (big) {
      return _Particle(
        r.nextDouble(),
        -0.05 - r.nextDouble() * 0.3,
        (r.nextDouble() - 0.5) * 0.15,
        0.15 + r.nextDouble() * 0.25,
        (r.nextDouble() - 0.5) * 12,
        color,
        5 + r.nextDouble() * 6,
      );
    }
    final angle = r.nextDouble() * 2 * math.pi;
    final speed = 0.25 + r.nextDouble() * 0.45;
    return _Particle(
      0.5,
      0.45,
      math.cos(angle) * speed * 0.8,
      math.sin(angle) * speed - 0.35,
      (r.nextDouble() - 0.5) * 14,
      color,
      4 + r.nextDouble() * 5,
    );
  }

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double spin;
  final Color color;
  final double size;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.burst) : super(repaint: burst.controller);

  final _Burst burst;

  static const _gravity = 0.9;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = burst.controller.value;
    final seconds = progress * burst.controller.duration!.inMilliseconds / 1000;
    final fade = progress < 0.75 ? 1.0 : (1 - progress) / 0.25;
    final paint = Paint();
    for (final p in burst.particles) {
      final x = (p.x + p.vx * seconds) * size.width;
      final y =
          (p.y + p.vy * seconds + 0.5 * _gravity * seconds * seconds * 0.3) *
          size.height;
      if (y > size.height + 20) continue;
      paint.color = p.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.spin * seconds);
      // Flat rectangles that "flip" by squashing, like paper confetti.
      final flip = math.cos(p.spin * seconds * 1.7).abs() * 0.8 + 0.2;
      canvas
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.55 * flip,
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.burst != burst;
}
