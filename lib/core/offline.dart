import 'big_number.dart';
import 'economy_engine.dart';
import 'game_state.dart';

/// Result of catching up on time the app was closed or in the background.
class OfflineReport {
  const OfflineReport({
    required this.state,
    required this.earned,
    required this.seconds,
    required this.capped,
  });

  /// State after the catch-up.
  final GameState state;
  final BigNumber earned;

  /// Seconds actually paid for (after the cap).
  final double seconds;

  /// Whether the player was away longer than the offline cap.
  final bool capped;

  bool get hasEarnings => !earned.isZero;
}

/// Advances [state] by the time between [lastSeenMs] and [nowMs], capped at
/// the configured offline limit.
///
/// [lastSeenMs] should be the latest timestamp ever seen, not the last save
/// time, so that turning the device clock back and forth cannot pay out the
/// same hours twice. A clock that moved backwards pays nothing.
OfflineReport catchUp(
  EconomyEngine engine,
  GameState state, {
  required int lastSeenMs,
  required int nowMs,
}) {
  final elapsed = (nowMs - lastSeenMs) / 1000;
  if (elapsed <= 0) {
    return OfflineReport(
      state: state,
      earned: BigNumber.zero,
      seconds: 0,
      capped: false,
    );
  }
  final cap = engine.config.offlineMaxSeconds;
  final seconds = elapsed > cap ? cap : elapsed;
  final next = engine.tick(state, seconds, countPlayTime: false);
  return OfflineReport(
    state: next,
    earned: next.cash - state.cash,
    seconds: seconds,
    capped: elapsed > cap,
  );
}
