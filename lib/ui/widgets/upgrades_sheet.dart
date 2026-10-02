import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../theme.dart';

/// Number of upgrades the player can afford right now (for the badge).
final affordableUpgradesProvider = Provider<int>((ref) {
  final state = ref.watch(gameProvider);
  final engine = ref.watch(engineProvider);
  return engine.config.upgrades
      .where((u) => engine.isUpgradeAvailable(state, u) && u.cost <= state.cash)
      .length;
});

Future<void> showUpgradesSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _UpgradesSheet(),
    );

class _UpgradesSheet extends ConsumerWidget {
  const _UpgradesSheet();

  /// Only the next few upgrades are shown to keep the list focused.
  static const _visible = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final upgrades = engine.config.upgrades
        .where((u) => engine.isUpgradeAvailable(state, u))
        .take(_visible)
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.upgrades,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (upgrades.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noUpgrades),
              ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: upgrades.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final u = upgrades[i];
                  final affordable = u.cost <= state.cash;
                  final multiplier = formatMultiplier(u.multiplier);
                  final title = u.affectsAllLines
                      ? l10n.upgradeAll(multiplier)
                      : l10n.upgradeLine(lineName(l10n, u.lineId), multiplier);
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          u.affectsAllLines
                              ? Icons.rocket_launch
                              : Icons.trending_up,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.background,
                            disabledBackgroundColor: const Color(0xFF242C4A),
                          ),
                          onPressed: affordable
                              ? () => ref
                                    .read(gameProvider.notifier)
                                    .buyUpgrade(u.id)
                              : null,
                          child: Text('\$${formatBig(u.cost)}'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
