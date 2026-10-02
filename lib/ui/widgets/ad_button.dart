import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_controller.dart';
import '../../game/monetization.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import 'chunky_button.dart';

/// Plays a rewarded ad and says so when none could be shown.
Future<bool> watchAd(
  BuildContext context,
  WidgetRef ref,
  AdPlacement placement,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final message = AppLocalizations.of(context).adUnavailable;
  final ok = await ref.read(adsProvider).watch(placement);
  if (!ok) messenger?.showSnackBar(SnackBar(content: Text(message)));
  return ok;
}

/// A button that plays a rewarded ad, then runs [onReward]. With "Remove
/// ads" bought it shows a gift icon and rewards right away.
class AdButton extends ConsumerWidget {
  const AdButton({
    super.key,
    required this.placement,
    required this.onReward,
    this.onStart,
    this.onSkipped,
    this.label,
    this.color = const Color(0xFFFFC44D),
    this.enabled = true,
    this.compact = false,
  });

  final AdPlacement placement;
  final VoidCallback onReward;

  /// Runs before the ad, e.g. to take an expiring event off screen.
  final VoidCallback? onStart;

  /// Runs when the ad was closed early or not available.
  final VoidCallback? onSkipped;
  final String? label;
  final Color color;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final free = ref.watch(gameProvider.select((s) => s.meta.adsRemoved));
    return ChunkyButton(
      color: color,
      radius: compact ? 10 : 14,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: enabled
          ? () async {
              onStart?.call();
              if (await watchAd(context, ref, placement)) {
                onReward();
              } else {
                onSkipped?.call();
              }
            }
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            free ? Icons.redeem : Icons.play_circle_fill,
            size: compact ? 14 : 18,
          ),
          const SizedBox(width: 4),
          Text(
            label ?? (free ? l10n.freeReward : l10n.watchAd),
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
