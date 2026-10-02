import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/number_format.dart';
import '../core/offline.dart';
import '../game/game_controller.dart';
import '../game/session.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';
import 'widgets/dev_menu.dart';
import 'widgets/line_card.dart';
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
    // A report from app start is shown once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final report = ref.read(offlineReportProvider);
      if (report != null) _showOffline(report);
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
      body: Column(
        children: [
          const _TopArea(),
          const _Toolbar(),
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
    );
  }
}

class _TopArea extends StatelessWidget {
  const _TopArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const SafeArea(bottom: false, child: StatusPanel()),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          SegmentedButton<BuyMode>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              selectedBackgroundColor: AppColors.accent,
              selectedForegroundColor: AppColors.background,
            ),
            segments: [
              const ButtonSegment(value: BuyMode.one, label: Text('×1')),
              const ButtonSegment(value: BuyMode.ten, label: Text('×10')),
              ButtonSegment(value: BuyMode.max, label: Text(l10n.buyModeMax)),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(buyModeProvider.notifier).select(s.first),
          ),
          const SizedBox(width: 8),
          const Spacer(),
          Flexible(
            flex: 4,
            child: Badge(
              isLabelVisible: affordable > 0,
              label: Text('$affordable'),
              backgroundColor: AppColors.warning,
              child: FilledButton.tonalIcon(
                onPressed: () => showUpgradesSheet(context),
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(l10n.upgrades),
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
