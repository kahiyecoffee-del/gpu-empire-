import 'dart:io' show Platform;

/// AdMob ad unit ids.
///
/// Only the Play Store build (`--dart-define=PRODUCTION_ADS=true`) uses the
/// real units; every other build uses Google's public test units, because
/// AdMob forbids testing with real ads. Empty real ids also fall back to
/// test units.
abstract final class AdIds {
  static const _production = bool.fromEnvironment('PRODUCTION_ADS');

  // Real ids (filled in from the AdMob console before release).
  static const _rewardedAndroid = 'ca-app-pub-4694724768236037/6135882052';
  static const _interstitialAndroid = '';
  static const _rewardedIos = '';
  static const _interstitialIos = '';

  static String _pick(String real, String test) =>
      _production && real.isNotEmpty ? real : test;

  static String get rewarded => Platform.isIOS
      ? _pick(_rewardedIos, 'ca-app-pub-3940256099942544/1712485313')
      : _pick(_rewardedAndroid, 'ca-app-pub-3940256099942544/5224354917');

  static String get interstitial => Platform.isIOS
      ? _pick(_interstitialIos, 'ca-app-pub-3940256099942544/4411468910')
      : _pick(_interstitialAndroid, 'ca-app-pub-3940256099942544/1033173712');
}
