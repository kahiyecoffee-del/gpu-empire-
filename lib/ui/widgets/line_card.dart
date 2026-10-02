import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/economy_config.dart';
import '../../core/game_state.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import '../line_style.dart';
import '../tutorial.dart';
import '../names.dart';
import '../theme.dart';
import 'ad_button.dart';
import 'chunky_button.dart';
import 'floating_gains.dart';
import 'glass_card.dart';
import 'icon_text.dart';
import 'iso_rack.dart';
import 'max_avatar.dart';

/// Racks drawn for a line: one more at these levels.
const _rackTiers = [10, 50];

/// Jobs shorter than this do not get a floating "+$" label each (too busy).
const _minLabelCycleSeconds = 0.4;

/// One production line: isometric rack art, job progress, level and buy
/// controls.
class LineCard extends ConsumerStatefulWidget {
  const LineCard({super.key, required this.index});

  final int index;

  @override
  ConsumerState<LineCard> createState() => _LineCardState();
}

class _LineCardState extends ConsumerState<LineCard>
    with TickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  String _burstText = '';
  final _gains = GlobalKey<FloatingGainsState>();

  @override
  void dispose() {
    _glow.dispose();
    _burst.dispose();
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
    final multiplier = crossed.fold(1.0, (p, m) => p * m.multiplier);
    setState(() => _burstText = '×${formatMultiplier(multiplier)}!');
    _burst.forward(from: 0);
  }

  /// Floats the job income up from the rack whenever a job completes.
  void _onLineTick(LineState? before, LineState after) {
    if (before == null) return;
    final finishedManual = before.running && !after.running;
    final wrapped = after.progress < before.progress && !finishedManual;
    if (!finishedManual && !wrapped) return;
    final state = ref.read(gameProvider);
    final engine = ref.read(engineProvider);
    if (engine.effectiveCycleSeconds(state, widget.index) <
        _minLabelCycleSeconds) {
      return;
    }
    _gains.currentState?.spawn(
      '+\$${formatBig(engine.incomePerJob(state, widget.index))}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    ref
      ..listen(
        gameProvider.select((s) => s.lines[i].level),
        (before, after) => _onLevelChanged(before ?? after, after),
      )
      ..listen(
        gameProvider.select((s) => ref.read(engineProvider).hasManager(s, i)),
        (before, after) {
          if (before == false && after) _glow.forward(from: 0);
        },
      )
      ..listen(gameProvider.select((s) => s.lines[i]), _onLineTick);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final line = state.lines[i];
    final config = engine.lineConfig(state, i);
    final style = LineStyle.forIndex(i);

    if (!line.isUnlocked) {
      return _LockedCard(index: i, canUnlock: engine.isAvailable(state, i));
    }

    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final managed = engine.hasManager(state, i);
    final working = managed || line.running;
    final progress = working ? line.progress / config.cycleSeconds : 0.0;
    final remaining = working
        ? (config.cycleSeconds - line.progress) / engine.efficiency(state)
        : engine.effectiveCycleSeconds(state, i);
    final milestone = engine.nextMilestone(line.level);
    final manager = engine.managerFor(state, i);
    final racks = 1 + _rackTiers.where((t) => line.level >= t).length;

    final card = AnimatedBuilder(
      animation: _glow,
      builder: (context, child) => GlassCard(
        tint: style.glow,
        padding: EdgeInsets.zero,
        highlight: _glow.isAnimating
            ? Color.lerp(style.glow, Colors.transparent, _glow.value)
            : null,
        child: child!,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          splashColor: style.glow.withValues(alpha: 0.15),
          onTap: () => ref.read(gameProvider.notifier).tap(i),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 12, 10),
            child: Row(
              children: [
                FloatingGains(
                  key: _gains,
                  color: style.led,
                  child: KeyedSubtree(
                    key: i == 0 ? TutorialKeys.rack : null,
                    child: SizedBox(
                      width: 84,
                      height: 92,
                      child: IsoRack(
                        style: style,
                        racks: racks,
                        active: working,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                lineName(l10n, config.id),
                                maxLines: 1,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _LevelBadge(
                            text: l10n.levelShort('${line.level}'),
                            color: style.glow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _JobProgress(
                        value: progress.clamp(0.0, 1.0),
                        label: working || !managed
                            ? '${remaining.toStringAsFixed(1)}s'
                            : '',
                        color: style.glow,
                        active: working,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.perJob(
                          '\$${formatBig(engine.incomePerJob(state, i))}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (milestone != null)
                        IconText(
                          Icons.flag_rounded,
                          l10n.nextMilestone(
                            '${milestone.level}',
                            formatMultiplier(milestone.multiplier),
                          ),
                          iconColor: style.led,
                          maxLines: 1,
                          style: textTheme.labelSmall?.copyWith(
                            color: style.led,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (manager != null) ...[
                        const SizedBox(height: 6),
                        _ManagerRow(
                          key: i == 0 ? TutorialKeys.manager : null,
                          manager: manager,
                          owned: managed,
                          color: style.glow,
                        ),
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
    return Stack(
      children: [
        card,
        Positioned.fill(
          child: IgnorePointer(
            child: MilestoneBurst(
              animation: _burst,
              text: _burstText,
              color: style.led,
            ),
          ),
        ),
      ],
    );
  }
}

/// "×2!" popping out of the card when a milestone is reached, with an
/// expanding ring.
class MilestoneBurst extends StatelessWidget {
  const MilestoneBurst({
    super.key,
    required this.animation,
    required this.text,
    required this.color,
  });

  final Animation<double> animation;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        if (!animation.isAnimating || t == 0) return const SizedBox.shrink();
        final pop = Curves.elasticOut.transform((t / 0.6).clamp(0.0, 1.0));
        final fade = t < 0.7 ? 1.0 : (1 - t) / 0.3;
        return CustomPaint(
          painter: _RingPainter(t, color),
          child: Center(
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.4 + 0.8 * pop,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: color, blurRadius: 18),
                      const Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.6 * Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * (1 - t)
        ..color = color.withValues(alpha: (1 - t) * 0.8),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}

class _JobProgress extends StatelessWidget {
  const _JobProgress({
    required this.value,
    required this.label,
    required this.color,
    required this.active,
  });

  final double value;
  final String label;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F22),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: value,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: active ? 0.7 : 0.3),
                      color.withValues(alpha: active ? 1 : 0.4),
                    ],
                  ),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color.lerp(color, Colors.white, 0.4),
        ),
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
    final state = ref.read(gameProvider);
    final near =
        !offer.affordable &&
        ref.read(engineProvider).isAvailable(state, index) &&
        ref.read(engineProvider).nearMissing(state, offer.cost) != null;
    final buy = SizedBox(
      key: index == 0 ? TutorialKeys.buy : null,
      width: 88,
      child: ChunkyButton(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        onPressed: offer.affordable
            ? () => ref.read(gameProvider.notifier).buyLevels(index, mode)
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l10n.buyButton('${offer.count}'),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${formatBig(offer.cost)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!near) return buy;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buy,
        const SizedBox(height: 4),
        AdButton(
          key: ValueKey('ad_get_$index'),
          placement: AdPlacement.nearUpgrade,
          compact: true,
          label: l10n.getItNow,
          onReward: () => ref
              .read(gameProvider.notifier)
              .buyLevelsWithGrant(index, ref.read(buyModeProvider)),
        ),
      ],
    );
  }
}

class _ManagerRow extends ConsumerWidget {
  const _ManagerRow({
    super.key,
    required this.manager,
    required this.owned,
    required this.color,
  });

  final ManagerConfig manager;
  final bool owned;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final name = managerName(l10n, manager.role);
    final bonus = managerBonus(l10n, manager);
    final portrait = PersonAvatar(
      look: PersonLook.forRole(manager.role),
      size: 26,
    );
    if (owned) {
      return Row(
        children: [
          portrait,
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (bonus.isNotEmpty)
                    TextSpan(
                      text: '  $bonus',
                      style: TextStyle(color: color),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      );
    }
    final affordable = ref.watch(
      gameProvider.select((s) => s.cash >= manager.cost),
    );
    return Row(
      children: [
        Opacity(opacity: 0.6, child: portrait),
        const SizedBox(width: 6),
        Flexible(
          child: ChunkyButton(
            color: AppColors.accentAlt,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            onPressed: affordable
                ? () => ref.read(gameProvider.notifier).buyManager(manager.id)
                : null,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${l10n.hireManager(name)} · \$${formatBig(manager.cost)}',
                maxLines: 1,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ),
      ],
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
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final config = engine.lineConfig(state, index);
    final style = LineStyle.forIndex(index);
    final textTheme = Theme.of(context).textTheme;
    final offer = ref.read(gameProvider.notifier).offer(index, BuyMode.one);
    return Opacity(
      opacity: canUnlock ? 1 : 0.5,
      child: GlassCard(
        tint: canUnlock ? style.glow : const Color(0xFF39415E),
        padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IsoRack(style: style, locked: true),
                  const Icon(
                    Icons.lock,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lineName(l10n, config.id),
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    canUnlock
                        ? '\$${formatBig(engine.levelCost(state, index, 1))}'
                        : l10n.lockedLine,
                    style: textTheme.bodySmall?.copyWith(
                      color: canUnlock ? style.led : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (canUnlock)
              ChunkyButton(
                color: style.glow,
                onPressed: offer.affordable
                    ? () => ref
                          .read(gameProvider.notifier)
                          .buyLevels(index, BuyMode.one)
                    : null,
                child: Text(l10n.unlockButton),
              ),
          ],
        ),
      ),
    );
  }
}
