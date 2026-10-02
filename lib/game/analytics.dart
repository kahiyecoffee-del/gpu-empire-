import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics_service.dart';
import '../services/remote_config.dart';
import 'game_events.dart';

/// Overridden in `main`.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => DebugAnalyticsService(),
);

/// Overridden in `main`.
final remoteConfigProvider = Provider<RemoteConfigService>(
  (ref) => const LocalRemoteConfig(),
);

/// Forwards game events to analytics. Taps are only counted per session,
/// not logged one by one.
final analyticsBridgeProvider = Provider<AnalyticsBridge>((ref) {
  final bridge = AnalyticsBridge(
    ref.watch(analyticsServiceProvider),
    ref.watch(gameEventsProvider),
  );
  ref.onDispose(bridge.dispose);
  return bridge;
});

class AnalyticsBridge {
  AnalyticsBridge(this._analytics, GameEventBus bus) {
    _sub = bus.stream.listen(_onEvent);
  }

  final AnalyticsService _analytics;
  late final StreamSubscription<GameEvent> _sub;
  int _taps = 0;

  void _onEvent(GameEvent e) {
    if (e.type == GameEventType.tap) {
      // The first tap matters for the tutorial funnel; the rest is noise.
      if (_taps++ == 0) _analytics.logEvent('first_tap', const {});
      return;
    }
    _analytics.logEvent(_name(e.type), e.params);
  }

  /// snake_case, as Firebase expects.
  static String _name(GameEventType type) => type.name.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );

  void dispose() => unawaited(_sub.cancel());
}
