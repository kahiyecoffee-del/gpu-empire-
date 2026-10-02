import 'dart:async';
import 'dart:io' show Platform;

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';

/// Google AdMob with the UMP consent flow.
///
/// Uses Google's public TEST ad units only. The real ids are added before
/// release.
class AdMobAdService implements AdService {
  static String get _rewardedId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/1712485313'
      : 'ca-app-pub-3940256099942544/5224354917';

  static String get _interstitialId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _started = false;

  @override
  Future<void> init() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        if (!updated.isCompleted) updated.complete();
      },
      (_) {
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;
    await _startIfAllowed();
  }

  Future<void> _startIfAllowed() async {
    if (_started || !await ConsentInformation.instance.canRequestAds()) {
      return;
    }
    _started = true;
    await MobileAds.instance.initialize();
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    await _startIfAllowed();
    final ad = _rewarded;
    if (ad == null) {
      if (_started) _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        closed.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final result = await closed.future;
    _loadRewarded();
    return result;
  }

  @override
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        closed.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        closed.complete();
      },
    );
    await ad.show();
    await closed.future;
    _loadInterstitial();
  }

  @override
  Future<bool> privacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @override
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((_) {});
    await _startIfAllowed();
  }
}
