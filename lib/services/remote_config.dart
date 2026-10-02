/// Remote overrides for game settings. Firebase Remote Config is connected
/// in Phase 5; [LocalRemoteConfig] returns no overrides until then.
abstract class RemoteConfigService {
  /// Fetches the latest values, giving up after a short timeout so the
  /// game never waits on the network.
  Future<void> init();

  /// Partial `economy.json` merged over the bundled file, e.g.
  /// `{"offline": {"maxSeconds": 10800}}`.
  Map<String, Object?> get economyOverrides;
}

class LocalRemoteConfig implements RemoteConfigService {
  const LocalRemoteConfig([this.economyOverrides = const {}]);

  @override
  final Map<String, Object?> economyOverrides;

  @override
  Future<void> init() async {}
}

/// Merges [overrides] into [base]: maps merge key by key, anything else
/// (numbers, strings, lists) is replaced.
Map<String, Object?> deepMerge(
  Map<String, Object?> base,
  Map<String, Object?> overrides,
) {
  final result = Map<String, Object?>.of(base);
  overrides.forEach((key, value) {
    final current = result[key];
    result[key] =
        current is Map<String, Object?> && value is Map<String, Object?>
        ? deepMerge(current, value)
        : value;
  });
  return result;
}
