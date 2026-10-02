import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/offline.dart';
import '../services/save_service.dart';
import 'analytics.dart';
import 'game_controller.dart';
import 'game_events.dart';
import 'monetization.dart';

/// Offline earnings computed at app start. Overridden in `main`.
final initialOfflineReportProvider = Provider<OfflineReport?>((ref) => null);

/// Offline earnings waiting to be shown to the player.
final offlineReportProvider =
    NotifierProvider<OfflineReportController, OfflineReport?>(
      OfflineReportController.new,
    );

class OfflineReportController extends Notifier<OfflineReport?> {
  @override
  OfflineReport? build() {
    final initial = ref.watch(initialOfflineReportProvider);
    return initial != null && _worthShowing(initial) ? initial : null;
  }

  // Short absences (e.g. watching an ad) are paid silently.
  bool _worthShowing(OfflineReport report) =>
      report.hasEarnings &&
      report.seconds >= ref.read(economyConfigProvider).offlineMinReportSeconds;

  void show(OfflineReport report) {
    if (_worthShowing(report)) state = report;
  }

  void dismiss() => state = null;
}

/// Saves every [interval] and whenever the app is backgrounded, and pays
/// offline earnings for the time spent in the background.
class GameSession extends ConsumerStatefulWidget {
  const GameSession({super.key, required this.child});

  static const interval = Duration(seconds: 10);

  final Widget child;

  @override
  ConsumerState<GameSession> createState() => _GameSessionState();
}

class _GameSessionState extends ConsumerState<GameSession> {
  late final Timer _timer;
  late final AppLifecycleListener _lifecycle;
  bool _away = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(GameSession.interval, (_) {
      // While hidden the game is frozen; saving would move the last-seen
      // time forward and swallow the offline earnings for that period.
      if (!_away) unawaited(_save());
    });
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    ref.read(analyticsBridgeProvider);
    final state = ref.read(gameProvider);
    ref.read(gameEventsProvider).emit(GameEventType.sessionStart, {
      'location': ref.read(engineProvider).location(state).id,
      'ipos': state.meta.ipoCount,
      'minutes': (state.playSeconds / 60).round(),
    });
    // Consent form, ad SDK and store start after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(adServiceProvider).init());
      unawaited(ref.read(storeProvider).init());
    });
  }

  SaveService get _saves => ref.read(saveServiceProvider);

  Future<void> _save() => _saves.save(ref.read(gameProvider));

  void _onHide() {
    if (_away) return;
    _away = true;
    unawaited(_save());
  }

  void _onShow() {
    if (!_away) return;
    _away = false;
    final report = catchUp(
      ref.read(engineProvider),
      ref.read(gameProvider),
      lastSeenMs: _saves.lastSeenMs,
      nowMs: _saves.now(),
    );
    ref.read(gameProvider.notifier).replace(report.state);
    ref.read(offlineReportProvider.notifier).show(report);
    unawaited(_save());
  }

  @override
  void dispose() {
    _timer.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
