import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/big_number.dart';
import '../../game/game_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../services/save_service.dart';
import '../theme.dart';
import 'icon_text.dart';

/// The hidden test menu is compiled into debug builds and into builds made
/// with `--dart-define=DEV_MENU=true` (the CI test builds). Store releases
/// leave it out.
const devMenuEnabled = !kReleaseMode || bool.fromEnvironment('DEV_MENU');

/// Taps on the build label needed to open the menu.
const devMenuTaps = 5;

Future<void> showDevMenu(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: AppColors.surface,
  builder: (context) => const _DevMenu(),
);

class _DevMenu extends ConsumerWidget {
  const _DevMenu();

  static final _cashGift = BigNumber.from(1e6);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timeScale = ref.watch(devSettingsProvider).timeScale;
    final game = ref.read(gameProvider.notifier);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: IconText(
              Icons.build,
              l10n.devMenu,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SwitchListTile(
            title: Text(l10n.devTimeScale),
            value: timeScale > 1,
            onChanged: (on) => ref
                .read(devSettingsProvider.notifier)
                .setTimeScale(on ? 10 : 1),
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: Text(l10n.devAddCash('\$1M')),
            onTap: () => game.devAddCash(_cashGift),
          ),
          ListTile(
            leading: const Icon(Icons.trending_up),
            title: Text(l10n.devMultiplyCash),
            onTap: () => game.devAddCash(ref.read(gameProvider).cash.scale(9)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.warning),
            title: Text(
              l10n.devReset,
              style: const TextStyle(color: AppColors.warning),
            ),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l10n.devResetConfirm),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              );
              if (confirmed ?? false) {
                await ref.read(saveServiceProvider).clear();
                game.devReset();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }
}
