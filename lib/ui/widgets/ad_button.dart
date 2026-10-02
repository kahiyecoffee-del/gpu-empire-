import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/game_controller.dart';
import '../../game/monetization.dart';
import '../../l10n/app_localizations.dart';
import '../../services/ad_service.dart';
import 'chunky_button.dart';
import 'toast.dart';

/// Plays a rewarded ad and says so when none could be shown.
Future<bool> watchAd(
  BuildContext context,
  WidgetRef ref,
  AdPlacement placement,
) async {
  final message = AppLocalizations.of(context).adUnavailable;
  final ok = await ref.read(adsProvider).watch(placement);
  if (!ok && context.mounted) showToast(context, message);
  return ok;
}

/// A button that plays a rewarded ad, then runs [onReward]. With "Remove
/// ads" bought it shows a gift icon and rewards right away. Ignores taps
/// while its ad is running, so a reward can never be claimed twice.
class AdButton extends ConsumerStatefulWidget {
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

  /// Runs after the ad, even if this button is gone by then (e.g. its sheet
  /// was closed), so it must not use this button's context.
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
  ConsumerState<AdButton> createState() => _AdButtonState();
}

class _AdButtonState extends ConsumerState<AdButton> {
  bool _busy = false;

  Future<void> _press() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Callbacks are taken now: the widget may be rebuilt or gone later.
    final onReward = widget.onReward;
    final onSkipped = widget.onSkipped;
    widget.onStart?.call();
    final ok = await watchAd(context, ref, widget.placement);
    if (ok) {
      onReward();
    } else {
      onSkipped?.call();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final free = ref.watch(gameProvider.select((s) => s.meta.adsRemoved));
    final compact = widget.compact;
    return ChunkyButton(
      color: widget.color,
      radius: compact ? 10 : 14,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onPressed: widget.enabled && !_busy ? _press : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            free ? Icons.redeem : Icons.play_circle_fill,
            size: compact ? 14 : 18,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              widget.label ?? (free ? l10n.freeReward : l10n.watchAd),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
