import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/big_number.dart';
import '../../core/number_format.dart';
import '../../core/quests.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../quest_texts.dart';
import '../theme.dart';
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
    final quest = ref.read(questBookProvider).current(ref.read(gameProvider));
    final reward = game.claimQuest();
    if (quest == null || reward == null) return;
    final l10n = AppLocalizations.of(context);
    _thanksTimer?.cancel();
    setState(() => _thanks = (questDone(l10n, quest.id), reward));
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
    final book = ref.watch(questBookProvider);
    final quest = book.current(state);
    final progress = quest == null ? null : book.progress(state, quest);
    final complete = progress?.isComplete ?? false;
    final thanks = _thanks;

    final String speech;
    Widget? footer;
    if (thanks != null) {
      speech = thanks.$1;
      footer = Text(
        l10n.questClaimed('\$${formatBig(thanks.$2)}'),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
        ),
      );
    } else if (quest == null) {
      speech = l10n.allQuestsDone;
    } else {
      speech = questAsk(l10n, quest.id);
      footer = _QuestFooter(
        quest: quest,
        progress: progress!,
        reward: book.reward(state, quest),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: complete && thanks == null
              ? AppColors.accent
              : const Color(0xFF242C4A),
          width: 1.5,
        ),
      ),
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
                if (footer != null) ...[const SizedBox(height: 6), footer],
              ],
            ),
          ),
          if (complete && thanks == null) ...[
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: _claim,
              child: Text(l10n.questClaim),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuestFooter extends StatelessWidget {
  const _QuestFooter({
    required this.quest,
    required this.progress,
    required this.reward,
  });

  final QuestConfig quest;
  final QuestProgress progress;
  final BigNumber reward;

  String _value(double v) => quest.type == QuestType.totalEarned
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
                    text: l10n.questProgress(
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
