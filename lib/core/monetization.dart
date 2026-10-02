/// Ad rewards, the lucky wheel, store products and interstitial rules, read
/// from the `monetization` section of `economy.json`.
class MonetizationConfig {
  const MonetizationConfig({
    this.overclockMultiplier = 2,
    this.overclockSecondsPerAd = 4 * 3600,
    this.overclockMaxSeconds = 12 * 3600,
    this.turboMultiplier = 5,
    this.turboSeconds = 120,
    this.offlineAdMultiplier = 3,
    this.eventAdMultiplier = 2,
    this.questAdMultiplier = 2,
    this.nearUpgradeMaxMissing = 0.25,
    this.interstitialGraceSeconds = 600,
    this.interstitialMinGapSeconds = 240,
    this.timeWarps = const [],
    this.products = const [],
    this.wheel = const WheelConfig(),
  });

  factory MonetizationConfig.fromJson(Map<String, Object?> json) {
    final ads = json['ads']! as Map<String, Object?>;
    return MonetizationConfig(
      overclockMultiplier: _d(ads['overclockMultiplier']),
      overclockSecondsPerAd: _d(ads['overclockSecondsPerAd']),
      overclockMaxSeconds: _d(ads['overclockMaxSeconds']),
      turboMultiplier: _d(ads['turboMultiplier']),
      turboSeconds: _d(ads['turboSeconds']),
      offlineAdMultiplier: _d(ads['offlineAdMultiplier']),
      eventAdMultiplier: _d(ads['eventAdMultiplier']),
      questAdMultiplier: _d(ads['questAdMultiplier']),
      nearUpgradeMaxMissing: _d(ads['nearUpgradeMaxMissing']),
      interstitialGraceSeconds: _d(ads['interstitialGraceSeconds']),
      interstitialMinGapSeconds: _d(ads['interstitialMinGapSeconds']),
      timeWarps: _list(json['timeWarps']).map(TimeWarpConfig.fromJson).toList(),
      products: _list(json['products']).map(ProductConfig.fromJson).toList(),
      wheel: WheelConfig.fromJson(json['wheel']! as Map<String, Object?>),
    );
  }

  /// "GPU Overclock": income multiplier while overclock time remains.
  final double overclockMultiplier;

  /// Overclock time added per rewarded ad.
  final double overclockSecondsPerAd;

  /// Overclock time can be stacked up to this.
  final double overclockMaxSeconds;

  /// "Turbo": a short, strong boost for an ad.
  final double turboMultiplier;
  final double turboSeconds;

  /// Offline earnings are multiplied by this after an ad.
  final double offlineAdMultiplier;

  /// Event and quest rewards are multiplied by these after an ad.
  final double eventAdMultiplier;
  final double questAdMultiplier;

  /// The "get it now" ad is offered when at most this share of the price is
  /// missing.
  final double nearUpgradeMaxMissing;

  /// No interstitials during the first [interstitialGraceSeconds] of a
  /// session, and at least [interstitialMinGapSeconds] between two.
  final double interstitialGraceSeconds;
  final double interstitialMinGapSeconds;

  final List<TimeWarpConfig> timeWarps;
  final List<ProductConfig> products;
  final WheelConfig wheel;

  ProductConfig product(String id) => products.firstWhere((p) => p.id == id);
}

/// Instantly collect [hours] of passive income for [tokens] GPU Tokens.
class TimeWarpConfig {
  const TimeWarpConfig({
    required this.id,
    required this.hours,
    required this.tokens,
  });

  factory TimeWarpConfig.fromJson(Map<String, Object?> json) => TimeWarpConfig(
    id: json['id']! as String,
    hours: _d(json['hours']),
    tokens: (json['tokens']! as num).toInt(),
  );

  final String id;
  final double hours;
  final int tokens;
}

enum ProductKind { consumable, nonConsumable }

/// A store product. Real prices come from the store; [fallbackPrice] is
/// only shown by the test store.
class ProductConfig {
  const ProductConfig({
    required this.id,
    required this.kind,
    required this.fallbackPrice,
    this.tokens = 0,
    this.removesAds = false,
    this.incomeMultiplier = 1,
  });

  factory ProductConfig.fromJson(Map<String, Object?> json) => ProductConfig(
    id: json['id']! as String,
    kind: ProductKind.values.byName(json['kind']! as String),
    fallbackPrice: json['fallbackPrice']! as String,
    tokens: (json['tokens'] as num?)?.toInt() ?? 0,
    removesAds: json['removesAds'] as bool? ?? false,
    incomeMultiplier: (json['incomeMultiplier'] as num?)?.toDouble() ?? 1,
  );

  final String id;
  final ProductKind kind;
  final String fallbackPrice;

  /// GPU Tokens granted.
  final int tokens;

  /// Removes interstitials and makes rewarded ads free.
  final bool removesAds;

  /// Permanent income multiplier (kept through IPOs).
  final double incomeMultiplier;
}

enum WheelPrizeKind { cash, boost, overclock, tokens }

class WheelPrize {
  const WheelPrize({
    required this.id,
    required this.kind,
    required this.value,
    this.seconds = 0,
    this.weight = 1,
  });

  factory WheelPrize.fromJson(Map<String, Object?> json) => WheelPrize(
    id: json['id']! as String,
    kind: WheelPrizeKind.values.byName(json['kind']! as String),
    value: _d(json['value']),
    seconds: _d(json['seconds'] ?? 0),
    weight: _d(json['weight'] ?? 1),
  );

  final String id;
  final WheelPrizeKind kind;

  /// Cash: seconds of full-speed income. Boost: multiplier. Overclock:
  /// seconds added. Tokens: count.
  final double value;

  /// Boost duration.
  final double seconds;
  final double weight;
}

/// Lucky wheel: a free spin every [freeEverySeconds], plus up to
/// [adSpinsPerDay] extra spins for rewarded ads.
class WheelConfig {
  const WheelConfig({
    this.freeEverySeconds = 4 * 3600,
    this.adSpinsPerDay = 3,
    this.prizes = const [],
  });

  factory WheelConfig.fromJson(Map<String, Object?> json) => WheelConfig(
    freeEverySeconds: _d(json['freeEverySeconds']),
    adSpinsPerDay: (json['adSpinsPerDay']! as num).toInt(),
    prizes: _list(json['prizes']).map(WheelPrize.fromJson).toList(),
  );

  final double freeEverySeconds;
  final int adSpinsPerDay;
  final List<WheelPrize> prizes;
}

/// Decides whether an interstitial may be shown now. Pure, so it is easy to
/// test: interstitials only at natural breaks (moving, after an IPO), never
/// in the first minutes of a session and never back to back.
class InterstitialPolicy {
  const InterstitialPolicy(this.config);

  final MonetizationConfig config;

  bool canShow({
    required double sessionSeconds,
    required double? secondsSinceLast,
    required bool adsRemoved,
  }) {
    if (adsRemoved) return false;
    if (sessionSeconds < config.interstitialGraceSeconds) return false;
    return secondsSinceLast == null ||
        secondsSinceLast >= config.interstitialMinGapSeconds;
  }
}

double _d(Object? value) => (value! as num).toDouble();

Iterable<Map<String, Object?>> _list(Object? value) =>
    (value! as List<Object?>).cast<Map<String, Object?>>();
