import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/economy_engine.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../theme.dart';
import '../names.dart';
import 'animated_money.dart';
import 'boosts_sheet.dart';
import 'chunky_button.dart';
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        children: [
          _LocationChip(name: locationName(l10n, engine.location(state).id)),
          AnimatedMoney(
            value: state.cash,
            style: textTheme.headlineLarge?.copyWith(
              fontSize: 38,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: AppColors.accent.withValues(alpha: 0.55),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                color: AppColors.accent,
                icon: income.isZero ? Icons.touch_app : Icons.trending_up,
                text: income.isZero
                    ? l10n.tapToRun
                    : l10n.cashPerSecond('\$${formatBig(income)}'),
              ),
              if (state.boost case final boost?)
                _Pill(
                  color: const Color(0xFFFF9F2E),
                  icon: Icons.local_fire_department,
                  text: l10n.boostActive(
                    formatMultiplier(boost.multiplier),
                    '${boost.secondsLeft.ceil()}',
                  ),
                ),
              if (state.meta.overclockSeconds > 0)
                GestureDetector(
                  onTap: () => showBoostsSheet(context),
                  child: _Pill(
                    color: const Color(0xFFFF5CC8),
                    icon: Icons.speed,
                    text: l10n.overclockLeft(
                      formatDuration(state.meta.overclockSeconds),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: _InfraGauge(kind: InfraKind.power)),
              SizedBox(width: 10),
              Expanded(child: _InfraGauge(kind: InfraKind.cooling)),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: efficiency < 1
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: IconText(
                        Icons.warning_amber_rounded,
                        l10n.throttled('${(efficiency * 100).floor()}'),
                        textAlign: TextAlign.center,
                        style: textTheme.labelMedium?.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: IconText(
        icon,
        text,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return IconText(
      Icons.place,
      name.toUpperCase(),
      iconColor: const Color(0xFFFFC44D),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary,
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
    final power = kind == InfraKind.power;
    final base = power ? const Color(0xFFFFC44D) : const Color(0xFF5CC8FF);
    final color = load > 1
        ? AppColors.warning
        : (load > 0.85 ? const Color(0xFFFF9F2E) : base);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              base.withValues(alpha: 0.10),
              const Color(0xFF141B36),
            ),
            const Color(0xFF0C1126),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  power ? Icons.bolt : Icons.ac_unit,
                  size: 16,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      power ? l10n.power : l10n.cooling,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
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
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF070B18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: load.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [color.withValues(alpha: 0.6), color],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: ChunkyButton(
              color: base,
              radius: 10,
              padding: const EdgeInsets.symmetric(vertical: 4),
              onPressed: affordable
                  ? () => ref.read(gameProvider.notifier).buyInfra(kind)
                  : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${l10n.upgradeInfra} · \$${formatBig(cost)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
