/// Where a rewarded ad is offered. Lets the ad network report per placement.
enum AdPlacement { overclock, turbo, offline, wheel, nearUpgrade, event, quest }

/// Shows ads. The game only talks to this interface, so the ad network can
/// be swapped and tests run without one.
abstract class AdService {
  /// Asks for consent where the law requires it (GDPR) and starts the SDK.
  Future<void> init();

  /// Shows a rewarded ad. True if the player watched it to the end.
  Future<bool> showRewarded(AdPlacement placement);

  /// Shows an interstitial if one is loaded.
  Future<void> showInterstitial();

  /// Whether the "Privacy options" entry must be shown in settings.
  Future<bool> privacyOptionsRequired();

  Future<void> showPrivacyOptions();
}

/// Grants every reward at once and never shows anything. Default for tests.
class InstantAdService implements AdService {
  const InstantAdService();

  @override
  Future<void> init() async {}

  @override
  Future<bool> showRewarded(AdPlacement placement) async => true;

  @override
  Future<void> showInterstitial() async {}

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
