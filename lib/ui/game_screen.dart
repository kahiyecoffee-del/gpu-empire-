import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/offline.dart';
import '../game/game_controller.dart';
import '../game/session.dart';
import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import 'theme.dart';
import 'widgets/advisor_banner.dart';
import 'widgets/chunky_button.dart';
import 'widgets/dev_menu.dart';
import 'widgets/game_background.dart';
import 'widgets/line_card.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/status_panel.dart';
import 'widgets/upgrades_sheet.dart';
import 'widgets/icon_text.dart';

/// Build identifier injected by CI (`--dart-define=BUILD_ID=<sha>`), so a
/// tester can confirm they are looking at the latest deploy.
const _buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// The single portrait game screen of the first location.
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // Max's greeting (first launch only), then any offline earnings from
    // app start, once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!ref.read(settingsProvider).introSeen) {
        await showIntroDialog(context);
        await ref.read(settingsProvider.notifier).markIntroSeen();
      }
      final report = ref.read(offlineReportProvider);
      if (report != null && mounted) await _showOffline(report);
    });
  }

  Future<void> _showOffline(OfflineReport report) async {
    final l10n = AppLocalizations.of(context);
    final cap = ref.read(engineProvider).config.offlineMaxSeconds;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: IconText(Icons.nightlight_round, l10n.offlineTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.offlineBody(
                '\$${formatBig(report.earned)}',
                formatDuration(report.seconds),
              ),
            ),
            if (report.capped) ...[
              const SizedBox(height: 8),
              Text(
                l10n.offlineCapped(formatDuration(cap)),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.background,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.collect),
          ),
        ],
      ),
    );
    ref.read(offlineReportProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(offlineReportProvider, (previous, next) {
      if (next != null && previous == null) _showOffline(next);
    });
    final lineCount = ref.watch(engineProvider).config.lines.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GameBackground(
        child: Column(
          children: [
            const _TopArea(),
            const _Toolbar(),
            const AdvisorBanner(),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                itemCount: lineCount + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) =>
                    i < lineCount ? LineCard(index: i) : const _BuildLabel(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopArea extends StatelessWidget {
  const _TopArea();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A2550),
            AppColors.surface.withValues(alpha: 0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            const StatusPanel(),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: AppLocalizations.of(context).settings,
                icon: const Icon(
                  Icons.settings,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => showSettingsSheet(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(buyModeProvider);
    final affordable = ref.watch(affordableUpgradesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F22),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (m, label) in [
                  (BuyMode.one, '×1'),
                  (BuyMode.ten, '×10'),
                  (BuyMode.max, l10n.buyModeMax),
                ])
                  GestureDetector(
                    onTap: () => ref.read(buyModeProvider.notifier).select(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: m == mode
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF6BF0B4), AppColors.accent],
                              )
                            : null,
                        boxShadow: m == mode
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: m == mode
                              ? AppColors.background
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Flexible(
            flex: 4,
            child: Badge(
              isLabelVisible: affordable > 0,
              label: Text('$affordable'),
              backgroundColor: AppColors.warning,
              child: ChunkyButton(
                color: const Color(0xFFB65CFF),
                foreground: Colors.white,
                onPressed: () => showUpgradesSheet(context),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.rocket_launch, size: 18),
                      const SizedBox(width: 6),
                      Text(l10n.upgrades),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Build label; tapping it [devMenuTaps] times opens the developer menu.
class _BuildLabel extends StatefulWidget {
  const _BuildLabel();

  @override
  State<_BuildLabel> createState() => _BuildLabelState();
}

class _BuildLabelState extends State<_BuildLabel> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: devMenuEnabled
          ? () {
              if (++_taps >= devMenuTaps) {
                _taps = 0;
                showDevMenu(context);
              }
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          AppLocalizations.of(context).buildInfo(_buildId),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
