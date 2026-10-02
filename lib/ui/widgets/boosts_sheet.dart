import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/monetization.dart';
import '../../core/number_format.dart';
import '../../game/game_controller.dart';
import '../../game/monetization.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import '../names.dart';
import '../theme.dart';
import 'ad_button.dart';
import 'chunky_button.dart';
import 'glass_card.dart';

const tokenColor = Color(0xFF5CC8FF);

Future<void> showBoostsSheet(BuildContext context, {bool shop = false}) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BoostsSheet(initialTab: shop ? 1 : 0),
    );

class _BoostsSheet extends ConsumerWidget {
  const _BoostsSheet({required this.initialTab});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tokens = ref.watch(gameProvider.select((s) => s.meta.tokens));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: DefaultTabController(
          length: 2,
          initialIndex: initialTab,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    Text(
                      l10n.boosts,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    TokenChip(tokens: tokens),
                  ],
                ),
              ),
              TabBar(
                indicatorColor: AppColors.accent,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: [
                  Tab(text: l10n.boostsTab),
                  Tab(text: l10n.shopTab),
                ],
              ),
              const Expanded(
                child: TabBarView(children: [_BoostsTab(), _ShopTab()]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TokenChip extends StatelessWidget {
  const TokenChip({super.key, required this.tokens});

  final int tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: tokenColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokenColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.memory, size: 16, color: tokenColor),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context).tokensBalance('$tokens'),
            style: const TextStyle(
              color: tokenColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostsTab extends ConsumerWidget {
  const _BoostsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final m = engine.config.monetization;
    final game = ref.read(gameProvider.notifier);
    final overclock = state.meta.overclockSeconds;
    final canAdd = engine.canAddOverclock(state);
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          tint: const Color(0xFFFF5CC8),
          highlight: overclock > 0 ? const Color(0xFFFF5CC8) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.speed, color: Color(0xFFFF5CC8), size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.overclockTitle,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          l10n.overclockBody(
                            formatMultiplier(m.overclockMultiplier),
                            formatMultiplier(m.overclockSecondsPerAd / 3600),
                            formatMultiplier(m.overclockMaxSeconds / 3600),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: overclock / m.overclockMaxSeconds,
                  minHeight: 8,
                  backgroundColor: const Color(0xFF0A0F22),
                  color: const Color(0xFFFF5CC8),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        overclock > 0
                            ? l10n.overclockLeft(formatDuration(overclock))
                            : '',
                        style: const TextStyle(
                          color: Color(0xFFFF5CC8),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AdButton(
                    key: const ValueKey('ad_overclock'),
                    placement: AdPlacement.overclock,
                    color: const Color(0xFFFF5CC8),
                    enabled: canAdd,
                    label: canAdd ? null : l10n.overclockFull,
                    onReward: game.addOverclock,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          tint: const Color(0xFFFF9F2E),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Color(0xFFFF9F2E),
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.turboTitle,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      l10n.turboBody(
                        formatMultiplier(m.turboMultiplier),
                        '${m.turboSeconds.round()}',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AdButton(
                key: const ValueKey('ad_turbo'),
                placement: AdPlacement.turbo,
                color: const Color(0xFFFF9F2E),
                onReward: game.turbo,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.timeWarpsTitle,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final warp in m.timeWarps)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _WarpTile(warp: warp),
          ),
      ],
    );
  }
}

class _WarpTile extends ConsumerWidget {
  const _WarpTile({required this.warp});

  final TimeWarpConfig warp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final affordable = state.meta.tokens >= warp.tokens;
    return GlassCard(
      tint: tokenColor,
      padding: const EdgeInsets.all(10),
      radius: 14,
      child: Row(
        children: [
          const Icon(Icons.fast_forward, color: tokenColor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.timeWarpItem(formatMultiplier(warp.hours)),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  l10n.timeWarpGain(
                    '\$${formatBig(engine.timeWarpValue(state, warp))}',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.accent),
                ),
              ],
            ),
          ),
          ChunkyButton(
            color: tokenColor,
            radius: 10,
            onPressed: () {
              if (affordable) {
                ref.read(gameProvider.notifier).timeWarp(warp);
              } else {
                DefaultTabController.of(context).animateTo(1);
                ScaffoldMessenger.maybeOf(
                  context,
                )?.showSnackBar(SnackBar(content: Text(l10n.notEnoughTokens)));
              }
            },
            child: Text(l10n.timeWarpCost('${warp.tokens}')),
          ),
        ],
      ),
    );
  }
}

class _ShopTab extends ConsumerWidget {
  const _ShopTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final products = ref.watch(engineProvider).config.monetization.products;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ProductTile(product: p),
          ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => ref.read(storeProvider).restore(),
            child: Text(l10n.restorePurchases),
          ),
        ),
      ],
    );
  }
}

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product});

  final ProductConfig product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(gameProvider);
    final engine = ref.watch(engineProvider);
    final owned = engine.ownsProduct(state, product);
    final store = ref.read(storeProvider);
    final (icon, color) = switch (product) {
      ProductConfig(removesAds: true) => (Icons.block, AppColors.warning),
      ProductConfig(incomeMultiplier: > 1) => (
        Icons.card_giftcard,
        const Color(0xFFFFC44D),
      ),
      _ => (Icons.memory, tokenColor),
    };
    return GlassCard(
      tint: color,
      highlight: product.incomeMultiplier > 1 && !owned ? color : null,
      padding: const EdgeInsets.all(12),
      radius: 16,
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName(l10n, product),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  productBody(l10n, product),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (owned)
            Text(
              l10n.owned,
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            ChunkyButton(
              color: color,
              radius: 10,
              onPressed: () => store.buy(product),
              child: Text(store.price(product)),
            ),
        ],
      ),
    );
  }
}
