import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/economy_engine.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import 'animated_money.dart';
import 'icon_text.dart';

/// Cash counter, income rate and the power/cooling gauges.
class StatusPanel extends ConsumerWidget {
  const StatusPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final income = engine.passiveIncomePerSecond(state);
    final efficiency = engine.efficiency(state);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          AnimatedMoney(
            value: state.cash,
            style: textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            income.isZero
                ? l10n.tapToRun
                : l10n.cashPerSecond('\$${formatBig(income)}'),
            style: textTheme.bodyMedium?.copyWith(color: AppColors.accent),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: _InfraGauge(kind: InfraKind.power)),
              SizedBox(width: 10),
              Expanded(child: _InfraGauge(kind: InfraKind.cooling)),
            ],
          ),
          if (efficiency < 1) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconText(
                Icons.warning_amber_rounded,
                l10n.throttled('${(efficiency * 100).floor()}'),
                textAlign: TextAlign.center,
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfraGauge extends ConsumerWidget {
  const _InfraGauge({required this.kind});

  final InfraKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final l10n = AppLocalizations.of(context);
    final load = engine.load(state, kind);
    final cost = engine.infraCost(state, kind);
    final affordable = cost <= state.cash;
    final color = load > 1
        ? AppColors.warning
        : (load > 0.85 ? const Color(0xFFFFB547) : AppColors.accent);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconText(
            kind == InfraKind.power ? Icons.bolt : Icons.ac_unit,
            kind == InfraKind.power ? l10n.power : l10n.cooling,
            iconColor: color,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.capacityUsage(
                formatPower(engine.demand(state, kind)),
                formatPower(engine.capacity(state, kind)),
              ),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: load.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: const Color(0xFF1B2240),
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 30,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: color,
                side: BorderSide(
                  color: affordable ? color : const Color(0xFF242C4A),
                ),
              ),
              onPressed: affordable
                  ? () => ref.read(gameProvider.notifier).buyInfra(kind)
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${l10n.upgradeInfra} · \$${formatBig(cost)}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
