import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/offline.dart';
import '../game/game_controller.dart';
import '../game/session.dart';
import '../l10n/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/settings_service.dart';
import 'names.dart';
import 'theme.dart';
import 'tutorial.dart';
import 'widgets/ad_button.dart';
import 'widgets/advisor_banner.dart';
import 'widgets/boosts_sheet.dart';
import 'widgets/chunky_button.dart';
import 'widgets/dev_menu.dart';
import 'widgets/event_bubble.dart';
import 'widgets/investors_sheet.dart';
import 'widgets/location_card.dart';
import 'widgets/game_background.dart';
import 'widgets/line_card.dart';
import 'widgets/settings_sheet.dart';
import 'widgets/status_panel.dart';
import 'widgets/upgrades_sheet.dart';
import 'widgets/icon_text.dart';
import 'widgets/wheel_sheet.dart';

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
      final settings = ref.read(settingsProvider.notifier);
      if (!ref.read(settingsProvider).introSeen) {
        await showIntroDialog(context);
        await settings.markIntroSeen();
      }
      // Players who are past the basics never see the tutorial.
      final s = ref.read(gameProvider);
      if (!ref.read(settingsProvider).tutorialDone &&
          (s.managers.isNotEmpty ||
              s.locationIndex > 0 ||
              s.meta.ipoCount > 0)) {
        await settings.setTutorialDone(done: true);
      }
      final report = ref.read(offlineReportProvider);
      if (report != null && mounted) await _showOffline(report);
    });
  }

  Future<void> _showOffline(OfflineReport report) async {
    final l10n = AppLocalizations.of(context);
    final engine = ref.read(engineProvider);
    final cap = engine.offlineCapSeconds(report.state);
    final multiplier = engine.config.monetization.offlineAdMultiplier;
    final game = ref.read(gameProvider.notifier);
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.collect),
          ),
          AdButton(
            key: const ValueKey('ad_offline'),
            placement: AdPlacement.offline,
            label: ref.read(gameProvider).meta.adsRemoved
                ? '${l10n.freeReward} ×${formatMultiplier(multiplier)}'
                : l10n.offlineAdButton(formatMultiplier(multiplier)),
            onReward: () {
              // The base amount is already paid; add the rest.
              game.addEarnings(report.earned.scale(multiplier - 1));
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
    ref.read(offlineReportProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    // Past the basics (moved on or went public): the tutorial is over and
    // the wheel and boosts appear.
    ref.listen(
      gameProvider.select((s) => s.locationIndex > 0 || s.meta.ipoCount > 0),
      (_, past) {
        if (past && !ref.read(settingsProvider).tutorialDone) {
          ref.read(settingsProvider.notifier).setTutorialDone(done: true);
        }
      },
    );
    ref.listen(offlineReportProvider, (previous, next) {
      if (next != null && previous == null) _showOffline(next);
    });
    final lineCount = ref.watch(gameProvider.select((s) => s.lines.length));
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(child: _body(lineCount)),
          const Positioned.fill(child: TutorialOverlay()),
        ],
      ),
    );
  }

  Widget _body(int lineCount) {
    return GameBackground(
      locationIndex: ref.watch(gameProvider.select((s) => s.locationIndex)),
      child: Column(
        children: [
          const _TopArea(),
          const _Toolbar(),
          Expanded(
            child: Stack(
              children: [
                ListView.separated(
                  // Room at the bottom so the floating buttons never
                  // cover the last card.
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 150),
                  itemCount: lineCount + 3,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == 0) return const AdvisorBanner();
                    if (i == 1) return const LocationCard();
                    if (i - 2 < lineCount) return LineCard(index: i - 2);
                    return const _BuildLabel();
                  },
                ),
                // Directional, so right-to-left languages mirror them too.
                const PositionedDirectional(
                  end: 12,
                  bottom: 16,
                  child: EventBubble(),
                ),
                const PositionedDirectional(
                  start: 12,
                  bottom: 16,
                  child: _SideButtons(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Round floating buttons for the lucky wheel and boosts.
class _SideButtons extends ConsumerWidget {
  const _SideButtons();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overclock = ref.watch(
      gameProvider.select((s) => s.meta.overclockSeconds > 0),
    );
    // New players first learn the basics; the extras appear afterwards.
    if (!ref.watch(settingsProvider.select((s) => s.tutorialDone))) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          key: const ValueKey('wheel_button'),
          icon: Icons.casino,
          label: l10n.wheel,
          color: const Color(0xFFFFC44D),
          badge: ref.watch(freeSpinReadyProvider),
          onTap: () => showWheelSheet(context),
        ),
        const SizedBox(height: 10),
        _RoundButton(
          key: const ValueKey('boosts_button'),
          icon: Icons.bolt,
          label: l10n.boosts,
          color: const Color(0xFFFF5CC8),
          badge: !overclock,
          onTap: () => showBoostsSheet(context),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Badge(
          isLabelVisible: badge,
          smallSize: 12,
          backgroundColor: AppColors.warning,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color.lerp(color, Colors.white, 0.35)!, color],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 14),
              ],
            ),
            child: Icon(icon, color: AppColors.background, size: 26),
          ),
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
            PositionedDirectional(
              top: 4,
              end: 4,
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
            flex: 3,
            child: Badge(
              isLabelVisible: ref.watch(ipoReadyProvider),
              label: const Icon(Icons.priority_high, size: 10),
              backgroundColor: AppColors.warning,
              child: ChunkyButton(
                color: const Color(0xFF4DA3FF),
                foreground: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                onPressed: () => showInvestorsSheet(context),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance, size: 18),
                      const SizedBox(width: 4),
                      Text(l10n.ipoShort),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 4,
            child: Badge(
              isLabelVisible: affordable > 0,
              label: Text('$affordable'),
              backgroundColor: AppColors.warning,
              child: ChunkyButton(
                color: const Color(0xFFB65CFF),
                foreground: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
