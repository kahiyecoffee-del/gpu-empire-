import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/big_number.dart';
import '../../core/economy_config.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../game/monetization.dart';
import '../../l10n/app_localizations.dart';
import '../names.dart';
import '../theme.dart';
import 'chunky_button.dart';
import 'glass_card.dart';

/// Whether an IPO would pay at least as many shares as the player holds,
/// a good moment to go public (drives the button's badge).
final ipoReadyProvider = Provider<bool>((ref) {
  final state = ref.watch(gameProvider);
  final engine = ref.watch(engineProvider);
  final preview = engine.sharesPreview(state);
  return preview >= BigNumber.one && preview >= state.meta.shares;
});

Future<void> showInvestorsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _InvestorsSheet(),
    );

class _InvestorsSheet extends StatelessWidget {
  const _InvestorsSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.investors,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: l10n.ipoTab),
                  Tab(text: l10n.skillsTab),
                ],
              ),
              const Expanded(
                child: TabBarView(children: [_IpoTab(), _SkillsTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IpoTab extends ConsumerWidget {
  const _IpoTab();

  String _percent(BigNumber shares, double perShare) =>
      formatBig(shares.scale(perShare * 100));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final perShare = engine.config.prestige.bonusPerShare;
    final held = state.meta.shares;
    final gain = engine.sharesPreview(state);
    final canIpo = engine.canIpo(state);
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          tint: AppColors.accentAlt,
          child: Row(
            children: [
              const Icon(Icons.pie_chart, color: AppColors.accentAlt, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.sharesHeld(formatBig(held)),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.shareBonus(_percent(held, perShare)),
                      style: const TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          tint: AppColors.accent,
          highlight: canIpo ? AppColors.accent : null,
          child: Column(
            children: [
              Text(
                l10n.ipoGainLabel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.ipoGain(formatBig(gain)),
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: canIpo ? AppColors.accent : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                canIpo
                    ? l10n.ipoAfter(_percent(held + gain, perShare))
                    : l10n.ipoNotYet,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ChunkyButton(
                  onPressed: canIpo ? () => _confirmIpo(context, ref) : null,
                  child: Text(l10n.ipoButton),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.ipoInfo(formatMultiplier(perShare * 100)),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Future<void> _confirmIpo(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(l10n.ipoConfirmTitle),
        content: Text(l10n.ipoConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          ChunkyButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.ipoButton),
          ),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    final gained = ref.read(gameProvider.notifier).goPublic();
    final ads = ref.read(adsProvider);
    if (context.mounted) Navigator.pop(context);
    if (gained != null) await ads.naturalBreak();
  }
}

class _SkillsTab extends ConsumerWidget {
  const _SkillsTab();

  static const _branches = ['income', 'infra', 'automation'];
  static const _branchIcons = {
    'income': Icons.trending_up,
    'infra': Icons.bolt,
    'automation': Icons.smart_toy,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.sharesHeld(formatBig(state.meta.shares)),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        for (final branch in _branches) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_branchIcons[branch], color: AppColors.accentAlt, size: 18),
              const SizedBox(width: 6),
              Text(
                branchName(l10n, branch),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accentAlt,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final skill in engine.config.skills.where(
            (s) => s.branch == branch,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SkillTile(skill: skill),
            ),
        ],
      ],
    );
  }
}

class _SkillTile extends ConsumerWidget {
  const _SkillTile({required this.skill});

  final SkillConfig skill;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final owned = state.meta.skills.contains(skill.id);
    final requires = skill.requires;
    final locked = requires != null && !state.meta.skills.contains(requires);
    final affordable = engine.canBuySkill(state, skill);

    final Widget trailing;
    if (owned) {
      trailing = const Icon(Icons.check_circle, color: AppColors.accent);
    } else {
      trailing = ChunkyButton(
        color: AppColors.accentAlt,
        radius: 10,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        onPressed: affordable
            ? () => ref.read(gameProvider.notifier).buySkill(skill.id)
            : null,
        child: Text(
          l10n.skillCost(formatBig(skill.cost)),
          style: const TextStyle(fontSize: 12),
        ),
      );
    }
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        radius: 14,
        tint: owned ? AppColors.accent : AppColors.accentAlt,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skillName(l10n, skill.id),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    skillEffect(l10n, skill),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (locked)
                    Text(
                      l10n.skillRequires(skillName(l10n, requires)),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
