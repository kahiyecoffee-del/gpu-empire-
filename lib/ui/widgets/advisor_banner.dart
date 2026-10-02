import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/big_number.dart';
import '../../core/number_format.dart';
import '../../core/economy_engine.dart';
import '../../core/quests.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../quest_texts.dart';
import '../theme.dart';
import 'chunky_button.dart';
import 'glass_card.dart';
import 'max_avatar.dart';

/// Max's speech bubble with the active side quest, its progress and reward.
class AdvisorBanner extends ConsumerStatefulWidget {
  const AdvisorBanner({super.key});

  @override
  ConsumerState<AdvisorBanner> createState() => _AdvisorBannerState();
}

class _AdvisorBannerState extends ConsumerState<AdvisorBanner> {
  /// How long Max's thank-you line stays up after a claim.
  static const _thanksDuration = Duration(seconds: 4);

  /// Thank-you line and reward of the quest just claimed, if any.
  (String, BigNumber)? _thanks;
  Timer? _thanksTimer;

  void _claim() {
    final game = ref.read(gameProvider.notifier);
    final (quest, isContract) = ref
        .read(questBoardProvider)
        .active(ref.read(gameProvider));
    final reward = game.claimQuest();
    if (reward == null) return;
    final l10n = AppLocalizations.of(context);
    _thanksTimer?.cancel();
    final line = isContract ? l10n.contractDone : questDone(l10n, quest.id);
    setState(() => _thanks = (line, reward));
    _thanksTimer = Timer(_thanksDuration, () {
      if (mounted) setState(() => _thanks = null);
    });
  }

  @override
  void dispose() {
    _thanksTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final board = ref.watch(questBoardProvider);
    final engine = ref.watch(engineProvider);
    final (quest, isContract) = board.active(state);
    final progress = board.progress(state, quest);
    final complete = progress.isComplete;
    final thanks = _thanks;

    final String speech;
    final Widget footer;
    if (thanks != null) {
      speech = thanks.$1;
      footer = Text(
        l10n.questClaimed('\$${formatBig(thanks.$2)}'),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      );
    } else {
      speech = isContract
          ? _contractText(l10n, engine, quest)
          : questAsk(l10n, quest.id);
      footer = _QuestFooter(
        quest: quest,
        progress: progress,
        reward: board.reward(state, quest),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(10),
      tint: AppColors.accentAlt,
      highlight: complete && thanks == null ? AppColors.accent : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MaxAvatar(excited: complete && thanks == null),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.advisorName} · ${l10n.advisorRole}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentAlt,
                  ),
                ),
                const SizedBox(height: 2),
                _Typewriter(text: speech),
                const SizedBox(height: 6),
                footer,
              ],
            ),
          ),
          if (complete && thanks == null) ...[
            const SizedBox(width: 8),
            ChunkyButton(onPressed: _claim, child: Text(l10n.questClaim)),
          ],
        ],
      ),
    );
  }
}

String _contractText(
  AppLocalizations l10n,
  EconomyEngine engine,
  QuestConfig contract,
) => contract.type == QuestType.lineLevel
    ? l10n.contractLevel(
        lineName(l10n, contract.target!),
        '${contract.amount.toInt()}',
      )
    : l10n.contractEarn('\$${formatDouble(contract.amount)}');

class _QuestFooter extends StatelessWidget {
  const _QuestFooter({
    required this.quest,
    required this.progress,
    required this.reward,
  });

  final QuestConfig quest;
  final QuestProgress progress;
  final BigNumber reward;

  String _value(double v) => quest.type == QuestType.reachLocation
      ? '${(v * 100).floor()}%'
      : _amount(v);

  String _amount(double v) =>
      quest.type == QuestType.totalEarned ||
          quest.type == QuestType.locationEarned
      ? '\$${formatDouble(v)}'
      : formatDouble(v.floorToDouble());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const small = TextStyle(fontSize: 11, color: AppColors.textSecondary);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFF0F1630),
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: quest.type == QuestType.reachLocation
                        ? _value(progress.current)
                        : l10n.questProgress(
                            _value(progress.current.clamp(0, progress.goal)),
                            _value(progress.goal),
                          ),
                  ),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: l10n.questReward('\$${formatBig(reward)}'),
                    style: const TextStyle(color: AppColors.accent),
                  ),
                ],
              ),
              style: small,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reveals [text] letter by letter, like Max is typing it.
class _Typewriter extends StatefulWidget {
  const _Typewriter({required this.text});

  final String text;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter>
    with SingleTickerProviderStateMixin {
  static const _perLetter = Duration(milliseconds: 22);

  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_Typewriter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _start();
  }

  void _start() {
    _controller
      ..duration = _perLetter * widget.text.length
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final shown = (widget.text.length * _controller.value).round();
        // The invisible remainder keeps the bubble from jumping in height.
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: widget.text.substring(0, shown)),
              TextSpan(
                text: widget.text.substring(shown),
                style: const TextStyle(color: Colors.transparent),
              ),
            ],
          ),
          style: const TextStyle(fontSize: 13, height: 1.3),
        );
      },
    );
  }
}
