import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../game/monetization.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../theme.dart';
import 'chunky_button.dart';
import 'glass_card.dart';
import 'icon_text.dart';

/// Progress towards the next location, with a Move button once reached.
class LocationCard extends ConsumerWidget {
  const LocationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final next = engine.nextLocation(state);
    final goal = engine.location(state).goal;
    if (next == null || goal == null) {
      return GlassCard(
        tint: const Color(0xFFFF5CC8),
        child: IconText(
          Icons.flag_circle,
          l10n.finalLocation,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    }
    final canMove = engine.canMove(state);
    final nextName = locationName(l10n, next.id);
    return GlassCard(
      tint: const Color(0xFFFFC44D),
      highlight: canMove ? const Color(0xFFFFC44D) : null,
      child: Row(
        children: [
          const Icon(Icons.local_shipping, color: Color(0xFFFFC44D), size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nextLocation(nextName),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: engine.locationProgress(state),
                    minHeight: 6,
                    backgroundColor: const Color(0xFF0A0F22),
                    color: const Color(0xFFFFC44D),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.locationGoal(
                      '\$${formatBig(state.locationEarned.min(goal))}',
                      '\$${formatBig(goal)}',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ChunkyButton(
            color: const Color(0xFFFFC44D),
            onPressed: canMove
                ? () => _confirmMove(context, ref, nextName)
                : null,
            child: Text(l10n.moveButton),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmMove(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.moveConfirmTitle(name)),
        content: Text(l10n.moveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ChunkyButton(
            color: const Color(0xFFFFC44D),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.moveButton),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    if (ref.read(gameProvider.notifier).moveToNextLocation()) {
      await ref.read(adsProvider).naturalBreak();
    }
  }
}
