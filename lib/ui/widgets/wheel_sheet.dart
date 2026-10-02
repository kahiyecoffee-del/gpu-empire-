import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/monetization.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import '../names.dart';
import '../theme.dart';
import 'ad_button.dart';
import 'chunky_button.dart';

/// Wall clock for the wheel; overridable in tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Whether the free spin is ready (drives the wheel button badge). Refreshes
/// with the game state, which changes every frame.
final freeSpinReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(gameProvider);
  final now = ref.watch(clockProvider)();
  return ref
      .watch(engineProvider)
      .freeSpinReady(state, now.millisecondsSinceEpoch);
});

Future<void> showWheelSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.surface,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => const _WheelSheet(),
);

const _segmentColors = [
  Color(0xFF3DDC97),
  Color(0xFFFF9F2E),
  Color(0xFF5CC8FF),
  Color(0xFFB65CFF),
  Color(0xFFFF5CC8),
  Color(0xFFFFC44D),
  Color(0xFF4DA3FF),
  Color(0xFF29E0D0),
];

class _WheelSheet extends ConsumerStatefulWidget {
  const _WheelSheet();

  @override
  ConsumerState<_WheelSheet> createState() => _WheelSheetState();
}

class _WheelSheetState extends ConsumerState<_WheelSheet>
    with SingleTickerProviderStateMixin {
  final _random = math.Random();
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  double _from = 0;
  double _to = 0;
  bool _spinning = false;
  String? _result;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  double get _angle =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value);

  Future<void> _go({required bool free}) async {
    if (_spinning) return;
    final game = ref.read(gameProvider.notifier);
    final prizes = ref.read(engineProvider).config.monetization.wheel.prizes;
    final index = ref.read(engineProvider).pickPrize(_random.nextDouble());
    final now = ref.read(clockProvider)();
    // Claim first so the spin cannot be lost or repeated if the sheet
    // closes mid-animation.
    final prize = game.spinWheel(index, free: free, now: now);
    if (prize == null) return;
    final l10n = AppLocalizations.of(context);
    final label = _describe(l10n, prize);
    final segment = 2 * math.pi / prizes.length;
    // The pointer is at the top; land on the middle of the won segment.
    final target = -(index + 0.5) * segment;
    final current = _angle % (2 * math.pi);
    setState(() {
      _spinning = true;
      _result = null;
      _from = current;
      _to = target - 2 * math.pi * 5;
      while (_to > _from - 2 * math.pi * 4) {
        _to -= 2 * math.pi;
      }
    });
    await _spin.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _spinning = false;
      _result = l10n.wheelWon(label);
    });
  }

  String _describe(AppLocalizations l10n, WheelPrize prize) {
    if (prize.kind != WheelPrizeKind.cash) return prizeLabel(l10n, prize);
    final state = ref.read(gameProvider);
    // Cash is already paid; show the amount it was worth.
    return l10n.prizeCash(
      '\$${formatBig(ref.read(engineProvider).prizeCash(state, prize))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final prizes = engine.config.monetization.wheel.prizes;
    final now = ref.watch(clockProvider)();
    final freeReady = engine.freeSpinReady(state, now.millisecondsSinceEpoch);
    final adLeft = engine.adSpinsLeft(state, dayKey(now));
    final size = math.min(MediaQuery.sizeOf(context).width - 64, 300.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.wheel,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  AnimatedBuilder(
                    animation: _spin,
                    builder: (context, _) => Transform.rotate(
                      angle: _angle,
                      child: CustomPaint(
                        size: Size.square(size),
                        painter: _WheelPainter(
                          labels: [for (final p in prizes) prizeLabel(l10n, p)],
                        ),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 48,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8)],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: Text(
                _result ?? '',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (freeReady)
              ChunkyButton(
                key: const ValueKey('wheel_free'),
                onPressed: _spinning ? null : () => _go(free: true),
                child: Text(l10n.wheelFreeSpin),
              )
            else ...[
              Text(
                l10n.wheelNextFree(
                  formatDuration(
                    engine.secondsToFreeSpin(state, now.millisecondsSinceEpoch),
                  ),
                ),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (adLeft > 0)
                AdButton(
                  key: const ValueKey('wheel_ad'),
                  placement: AdPlacement.wheel,
                  enabled: !_spinning,
                  label: l10n.wheelAdSpin('$adLeft'),
                  onReward: () => unawaited(_go(free: false)),
                )
              else
                Text(
                  l10n.wheelNoSpins,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels});

  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final segment = 2 * math.pi / labels.length;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < labels.length; i++) {
      // Segment i spans clockwise from the top.
      final start = -math.pi / 2 + i * segment;
      final color = _segmentColors[i % _segmentColors.length];
      canvas.drawArc(rect, start, segment, true, Paint()..color = color);
      canvas.drawArc(
        rect,
        start,
        segment,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppColors.background,
      );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(start + segment / 2 + math.pi / 2);
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            fontFamily: 'Inter',
            color: AppColors.background,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
      )..layout(maxWidth: radius * 0.55);
      painter.paint(canvas, Offset(-painter.width / 2, -radius * 0.82));
      canvas.restore();
    }
    canvas.drawCircle(
      center,
      radius * 0.14,
      Paint()..color = AppColors.surface,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.labels != labels;
}
