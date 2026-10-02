import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';
import 'ad_service.dart';

/// Google AdMob with the UMP consent flow.
///
/// Ad unit ids come from [AdIds]: test units except in the store build.
class AdMobAdService implements AdService {
  static String get _rewardedId => AdIds.rewarded;

  static String get _interstitialId => AdIds.interstitial;

  /// Waits between retries after a failed load (no fill, offline).
  static const _retryDelays = [10, 30, 60, 120, 300];

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _loadingRewarded = false;
  bool _loadingInterstitial = false;
  int _rewardedFailures = 0;
  int _interstitialFailures = 0;

  /// Shared, so overlapping callers start the SDK only once.
  Future<bool>? _starting;
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

  Future<bool> _startIfAllowed() {
    if (_started) return Future.value(true);
    return _starting ??= () async {
      try {
        if (!await ConsentInformation.instance.canRequestAds()) return false;
        await MobileAds.instance.initialize();
        _started = true;
        _loadRewarded();
        _loadInterstitial();
        return true;
      } finally {
        // Allow a new attempt later (e.g. after consent is given).
        _starting = null;
      }
    }();
  }

  Duration _retryAfter(int failures) => Duration(
    seconds: _retryDelays[(failures - 1).clamp(0, _retryDelays.length - 1)],
  );

  void _loadRewarded() {
    if (!_started || _rewarded != null || _loadingRewarded) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewarded = false;
          _rewardedFailures = 0;
          _rewarded = ad;
        },
        onAdFailedToLoad: (_) {
          _loadingRewarded = false;
          Timer(_retryAfter(++_rewardedFailures), _loadRewarded);
        },
      ),
    );
  }

  void _loadInterstitial() {
    if (!_started || _interstitial != null || _loadingInterstitial) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitial = false;
          _interstitialFailures = 0;
          _interstitial = ad;
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitial = false;
          Timer(_retryAfter(++_interstitialFailures), _loadInterstitial);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded(AdPlacement placement) async {
    await _startIfAllowed();
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    final result = await closed.future;
    _loadRewarded();
    return result;
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return false;
    }
    _interstitial = null;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show();
    final shown = await closed.future;
    _loadInterstitial();
    return shown;
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
