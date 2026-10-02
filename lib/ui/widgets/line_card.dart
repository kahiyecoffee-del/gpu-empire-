import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../theme.dart';
import 'server_rack.dart';
import 'icon_text.dart';

/// One production line: rack art, progress, level and buy controls.
class LineCard extends ConsumerStatefulWidget {
  const LineCard({super.key, required this.index});

  final int index;

  @override
  ConsumerState<LineCard> createState() => _LineCardState();
}

class _LineCardState extends ConsumerState<LineCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  void _onLevelChanged(int before, int after) {
    if (after <= before) return;
    _glow.forward(from: 0);
    final engine = ref.read(engineProvider);
    final crossed = engine.config.milestones
        .where((m) => m.level > before && m.level <= after)
        .toList();
    if (crossed.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final multiplier = crossed.fold(1.0, (p, m) => p * m.multiplier);
    final name = lineName(l10n, engine.config.lines[widget.index].id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
          content: IconText(
            Icons.celebration,
            l10n.milestoneReached(name, formatMultiplier(multiplier)),
            style: const TextStyle(
              color: AppColors.background,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      gameProvider.select((s) => s.lines[widget.index].level),
      (before, after) => _onLevelChanged(before ?? after, after),
    );
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final i = widget.index;
    final line = state.lines[i];

    if (!line.isUnlocked) {
      return engine.isAvailable(state, i)
          ? _LockedCard(index: i, canUnlock: true)
          : _LockedCard(index: i, canUnlock: false);
    }

    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final config = engine.config.lines[i];
    final managed = engine.hasManager(state, i);
    final working = managed || line.running;
    final cycle = engine.effectiveCycleSeconds(state, i);
    final progress = working ? line.progress / config.cycleSeconds : 0.0;
    final remaining = working
        ? (config.cycleSeconds - line.progress) / engine.efficiency(state)
        : cycle;
    final milestone = engine.nextMilestone(line.level);
    final manager = engine.config.managerForLine(config.id);

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        final t = 1 - _glow.value;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF242C4A),
                AppColors.accent,
                _glow.isAnimating ? t : 0,
              )!,
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => ref.read(gameProvider.notifier).tap(i),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 64,
                  child: ServerRack(
                    units: (line.level ~/ 10 + 2).clamp(2, 6),
                    active: working,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              lineName(l10n, config.id),
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _Badge(text: l10n.levelShort('${line.level}')),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _JobProgress(
                        value: progress.clamp(0.0, 1.0),
                        label: '${remaining.toStringAsFixed(1)}s',
                        highlight: working,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.perJob(
                          '\$${formatBig(engine.incomePerJob(state, i))}',
                        ),
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (milestone != null)
                        Text(
                          l10n.nextMilestone(
                            '${milestone.level}',
                            formatMultiplier(milestone.multiplier),
                          ),
                          style: textTheme.labelSmall?.copyWith(
                            color: AppColors.accentAlt,
                          ),
                        ),
                      if (manager != null) ...[
                        const SizedBox(height: 4),
                        _ManagerRow(managerId: manager.id, owned: managed),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _BuyButton(index: i),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JobProgress extends StatelessWidget {
  const _JobProgress({
    required this.value,
    required this.label,
    required this.highlight,
  });

  final double value;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 16,
            backgroundColor: const Color(0xFF0F1630),
            color: highlight ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF242C4A),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _BuyButton extends ConsumerWidget {
  const _BuyButton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gameProvider);
    final mode = ref.watch(buyModeProvider);
    final offer = ref.read(gameProvider.notifier).offer(index, mode);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: 92,
      child: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          disabledBackgroundColor: const Color(0xFF242C4A),
          disabledForegroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: offer.affordable
            ? () => ref.read(gameProvider.notifier).buyLevels(index, mode)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.buyButton('${offer.count}'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              '\$${formatBig(offer.cost)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerRow extends ConsumerWidget {
  const _ManagerRow({required this.managerId, required this.owned});

  final String managerId;
  final bool owned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = managerName(l10n, managerId);
    if (owned) {
      return IconText(
        Icons.person,
        l10n.managerWorking(name),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.accent),
      );
    }
    final engine = ref.watch(engineProvider);
    final cost = engine.config.managers
        .firstWhere((m) => m.id == managerId)
        .cost;
    final affordable = ref.watch(gameProvider.select((s) => s.cash >= cost));
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          foregroundColor: AppColors.accentAlt,
          side: BorderSide(
            color: affordable ? AppColors.accentAlt : const Color(0xFF242C4A),
          ),
        ),
        onPressed: affordable
            ? () => ref.read(gameProvider.notifier).buyManager(managerId)
            : null,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: IconText(
            Icons.person_add,
            '${l10n.hireManager(name)} · \$${formatBig(cost)}',
            maxLines: 1,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _LockedCard extends ConsumerWidget {
  const _LockedCard({required this.index, required this.canUnlock});

  final int index;
  final bool canUnlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final engine = ref.watch(engineProvider);
    final config = engine.config.lines[index];
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: canUnlock ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF242C4A)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 44,
              height: 64,
              child: Icon(Icons.lock_outline, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lineName(l10n, config.id),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    canUnlock
                        ? '\$${formatBig(engine.levelCost(ref.watch(gameProvider), index, 1))}'
                        : l10n.lockedLine,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canUnlock) _UnlockButton(index: index),
          ],
        ),
      ),
    );
  }
}

class _UnlockButton extends ConsumerWidget {
  const _UnlockButton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(gameProvider);
    final offer = ref.read(gameProvider.notifier).offer(index, BuyMode.one);
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accentAlt,
        foregroundColor: AppColors.background,
        disabledBackgroundColor: const Color(0xFF242C4A),
      ),
      onPressed: offer.affordable
          ? () => ref.read(gameProvider.notifier).buyLevels(index, BuyMode.one)
          : null,
      child: Text(AppLocalizations.of(context).unlockButton),
    );
  }
}
