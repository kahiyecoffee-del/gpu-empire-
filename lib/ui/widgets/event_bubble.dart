import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/economy_config.dart';
import '../../core/number_format.dart';
import '../../game/events.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../theme.dart';

/// A pulsing bubble for the active random event. Tapping it collects the
/// reward; it fades away when the event expires.
class EventBubble extends ConsumerStatefulWidget {
  const EventBubble({super.key});

  @override
  ConsumerState<EventBubble> createState() => _EventBubbleState();
}

class _EventBubbleState extends ConsumerState<EventBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(eventProvider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: active == null
          ? const SizedBox.shrink()
          : _bubble(context, active.event),
    );
  }

  Widget _bubble(BuildContext context, EventConfig event) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final reward = switch (event.kind) {
      EventKind.boost => l10n.eventBoost(
        formatMultiplier(event.value),
        '${event.seconds.round()}',
      ),
      EventKind.cash => l10n.eventCash(
        '\$${formatBig(engine.fullRate(state).scale(event.value))}',
      ),
    };
    const color = Color(0xFFFF9F2E);
    return GestureDetector(
      key: ValueKey(event.id),
      onTap: () => ref.read(eventProvider.notifier).collect(),
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.05 * math.sin(_pulse.value * math.pi),
          child: child,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [Color(0xFFFFC44D), color]),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 18),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                event.kind == EventKind.boost
                    ? Icons.local_fire_department
                    : Icons.card_giftcard,
                color: AppColors.background,
                size: 28,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      eventTitle(l10n, event.id),
                      style: const TextStyle(
                        color: AppColors.background,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      reward,
                      style: const TextStyle(
                        color: AppColors.background,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.eventTap,
                      style: TextStyle(
                        color: AppColors.background.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
