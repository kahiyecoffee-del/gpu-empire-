import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_controller.dart';
import '../game/game_events.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import 'theme.dart';
import 'widgets/max_avatar.dart';

/// Widgets the tutorial can point at.
abstract final class TutorialKeys {
  static final rack = GlobalKey(debugLabel: 'tutorial_rack');
  static final buy = GlobalKey(debugLabel: 'tutorial_buy');
  static final manager = GlobalKey(debugLabel: 'tutorial_manager');
  static final infra = GlobalKey(debugLabel: 'tutorial_infra');
}

enum TutorialStep { tap, save, buy, manager, done, infra }

/// What the tutorial shows right now: Max's line and what he points at.
class TutorialTip {
  const TutorialTip(this.step, this.target);

  final TutorialStep step;

  /// Null for steps without a highlight (the closing message).
  final GlobalKey? target;

  /// Steps the player confirms with a button instead of an action.
  bool get needsOk => step == TutorialStep.done || step == TutorialStep.infra;
}

/// The tutorial follows the game state, so nothing but "finished" has to
/// be saved: first run a job, then buy a rack, then hire the first manager
/// once it is affordable. A one-time hint explains the throttle later.
final tutorialProvider = Provider<TutorialTip?>((ref) {
  final settings = ref.watch(settingsProvider);
  final state = ref.watch(gameProvider);
  final engine = ref.watch(engineProvider);

  if (!settings.tutorialDone) {
    if (state.locationIndex != 0) return null;
    final line = state.lines[0];
    if (state.manualJobs == 0 && !line.running) {
      return TutorialTip(TutorialStep.tap, TutorialKeys.rack);
    }
    if (line.level < 2) {
      // What the highlighted button offers in the current buy mode.
      final affordable = ref
          .read(gameProvider.notifier)
          .offer(0, ref.watch(buyModeProvider))
          .affordable;
      return affordable
          ? TutorialTip(TutorialStep.buy, TutorialKeys.buy)
          : TutorialTip(TutorialStep.save, TutorialKeys.rack);
    }
    if (!engine.hasManager(state, 0)) {
      final manager = engine.managerFor(state, 0);
      final affordable = manager != null && manager.cost <= state.cash;
      // Quiet until the manager is affordable: no nagging meanwhile.
      return affordable
          ? TutorialTip(TutorialStep.manager, TutorialKeys.manager)
          : null;
    }
    return const TutorialTip(TutorialStep.done, null);
  }
  if (!settings.infraHintSeen && engine.efficiency(state) < 1) {
    return TutorialTip(TutorialStep.infra, TutorialKeys.infra);
  }
  return null;
});

String _text(AppLocalizations l10n, TutorialStep step) => switch (step) {
  TutorialStep.tap => l10n.tutorialTap,
  TutorialStep.save => l10n.tutorialSave,
  TutorialStep.buy => l10n.tutorialBuy,
  TutorialStep.manager => l10n.tutorialManager,
  TutorialStep.done => l10n.tutorialDone,
  TutorialStep.infra => l10n.tutorialInfra,
};

/// Dims the screen around the target, rings it and shows Max's bubble.
/// Taps go through to the game, so the player does the real action.
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  /// The target's rectangle in this overlay's coordinates, from the last
  /// layout (the game rebuilds every frame, so it follows scrolling).
  Rect? _targetRect(GlobalKey? key) {
    final target = key?.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (target is! RenderBox ||
        self is! RenderBox ||
        !target.attached ||
        !target.hasSize ||
        !self.hasSize) {
      return null;
    }
    final topLeft = self.globalToLocal(target.localToGlobal(Offset.zero));
    return topLeft & target.size;
  }

  Future<void> _finish(TutorialStep step) async {
    final settings = ref.read(settingsProvider.notifier);
    if (step == TutorialStep.infra) {
      await settings.setInfraHintSeen();
    } else {
      await settings.setTutorialDone(done: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tutorialProvider.select((t) => t?.step), (before, after) {
      // Leaving the throttle hint by fixing it counts as seen.
      if (before == TutorialStep.infra && after == null) {
        ref.read(settingsProvider.notifier).setInfraHintSeen();
      }
      if (after != null && after != before) {
        ref.read(gameEventsProvider).emit(GameEventType.tutorialStep, {
          'step': after.name,
        });
      }
    });
    final tip = ref.watch(tutorialProvider);
    if (tip == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final rect = _targetRect(tip.target);
    final size = MediaQuery.sizeOf(context);
    final bubbleOnTop = rect != null && rect.center.dy > size.height * 0.5;

    final bubble = _MaxBubble(
      text: _text(l10n, tip.step),
      okLabel: tip.needsOk
          ? (tip.step == TutorialStep.done
                ? l10n.tutorialLetsGo
                : l10n.tutorialGotIt)
          : null,
      onOk: () => _finish(tip.step),
      onSkip: tip.step == TutorialStep.infra || tip.step == TutorialStep.done
          ? null
          : () => _finish(tip.step),
      skipLabel: l10n.tutorialSkip,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => CustomPaint(
                painter: _SpotlightPainter(
                  rect: rect?.inflate(6),
                  pulse: _pulse.value,
                  // The closing message dims less: nothing to point at.
                  dim: rect == null ? 0.35 : 0.55,
                ),
              ),
            ),
          ),
        ),
        if (rect != null)
          Positioned(
            left: rect.center.dx - 4,
            top: rect.bottom - 10,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.translate(
                  offset: Offset(
                    0,
                    6 *
                        Curves.easeInOut.transform(
                          (_pulse.value * 2 - 1).abs(),
                        ),
                  ),
                  child: child,
                ),
                child: const Icon(
                  Icons.touch_app,
                  size: 44,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          top: bubbleOnTop ? MediaQuery.paddingOf(context).top + 8 : null,
          bottom: bubbleOnTop ? null : 24,
          child: bubble,
        ),
      ],
    );
  }
}

class _MaxBubble extends StatelessWidget {
  const _MaxBubble({
    required this.text,
    required this.okLabel,
    required this.onOk,
    required this.onSkip,
    required this.skipLabel,
  });

  final String text;
  final String? okLabel;
  final VoidCallback onOk;
  final VoidCallback? onSkip;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('tutorial_bubble'),
      color: AppColors.surface,
      elevation: 12,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MaxAvatar(size: 48, excited: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (onSkip != null)
                        TextButton(
                          onPressed: onSkip,
                          child: Text(
                            skipLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (okLabel != null)
                        TextButton(
                          key: const ValueKey('tutorial_ok'),
                          onPressed: onOk,
                          child: Text(
                            okLabel!,
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.rect,
    required this.pulse,
    required this.dim,
  });

  final Rect? rect;
  final double pulse;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final r = rect;
    if (r == null) {
      canvas.drawPath(
        screen,
        Paint()..color = Colors.black.withValues(alpha: dim),
      );
      return;
    }
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(18));
    canvas.drawPath(
      Path.combine(PathOperation.difference, screen, Path()..addRRect(hole)),
      Paint()..color = Colors.black.withValues(alpha: dim),
    );
    // A ring that grows and fades, drawing the eye to the hole.
    canvas.drawRRect(
      hole.inflate(10 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = AppColors.accent.withValues(alpha: 1 - pulse),
    );
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.rect != rect || old.pulse != pulse || old.dim != dim;
}
