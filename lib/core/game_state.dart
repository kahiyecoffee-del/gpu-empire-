import 'big_number.dart';
import 'economy_config.dart';

/// State of one production line.
class LineState {
  const LineState({this.level = 0, this.progress = 0, this.running = false});

  factory LineState.fromJson(Map<String, Object?> json) => LineState(
    level: (json['level']! as num).toInt(),
    progress: (json['progress']! as num).toDouble(),
    running: json['running']! as bool,
  );

  /// Number of racks owned; 0 means the line is locked.
  final int level;

  /// Seconds of work done on the current job.
  final double progress;

  /// Whether a manually started job is in progress. Managed lines ignore it.
  final bool running;

  bool get isUnlocked => level > 0;

  LineState copyWith({int? level, double? progress, bool? running}) =>
      LineState(
        level: level ?? this.level,
        progress: progress ?? this.progress,
        running: running ?? this.running,
      );

  Map<String, Object?> toJson() => {
    'level': level,
    'progress': progress,
    'running': running,
  };
}

/// A temporary income multiplier, e.g. from a random event.
class Boost {
  const Boost({required this.multiplier, required this.secondsLeft});

  factory Boost.fromJson(Map<String, Object?> json) => Boost(
    multiplier: (json['multiplier']! as num).toDouble(),
    secondsLeft: (json['secondsLeft']! as num).toDouble(),
  );

  final double multiplier;
  final double secondsLeft;

  Map<String, Object?> toJson() => {
    'multiplier': multiplier,
    'secondsLeft': secondsLeft,
  };
}

/// A contract as issued: frozen so its goal does not move while the
/// player works on it.
class ContractState {
  const ContractState({required this.type, required this.amount, this.target});

  factory ContractState.fromJson(Map<String, Object?> json) => ContractState(
    type: json['type']! as String,
    target: json['target'] as String?,
    amount: (json['amount']! as num).toDouble(),
  );

  /// Name of a quest type, e.g. `lineLevel`.
  final String type;
  final String? target;
  final double amount;

  Map<String, Object?> toJson() => {
    'type': type,
    'target': target,
    'amount': amount,
  };
}

/// Progress that survives an IPO.
class MetaState {
  const MetaState({
    this.shares = BigNumber.zero,
    this.skills = const {},
    this.ipoCount = 0,
    this.storyIndex = 0,
    this.lifetimeEarned = BigNumber.zero,
  });

  factory MetaState.fromJson(Map<String, Object?> json) => MetaState(
    shares: BigNumber.parse(json['shares']! as String),
    skills: (json['skills']! as List<Object?>).cast<String>().toSet(),
    ipoCount: (json['ipoCount']! as num).toInt(),
    storyIndex: (json['storyIndex']! as num).toInt(),
    lifetimeEarned: BigNumber.parse(json['lifetimeEarned']! as String),
  );

  /// Unspent shares; each adds the configured income bonus.
  final BigNumber shares;

  /// Ids of bought investor skills.
  final Set<String> skills;
  final int ipoCount;

  /// Index of Max's active story quest.
  final int storyIndex;
  final BigNumber lifetimeEarned;

  MetaState copyWith({
    BigNumber? shares,
    Set<String>? skills,
    int? ipoCount,
    int? storyIndex,
    BigNumber? lifetimeEarned,
  }) => MetaState(
    shares: shares ?? this.shares,
    skills: skills ?? this.skills,
    ipoCount: ipoCount ?? this.ipoCount,
    storyIndex: storyIndex ?? this.storyIndex,
    lifetimeEarned: lifetimeEarned ?? this.lifetimeEarned,
  );

  Map<String, Object?> toJson() => {
    'shares': shares.toJson(),
    'skills': skills.toList()..sort(),
    'ipoCount': ipoCount,
    'storyIndex': storyIndex,
    'lifetimeEarned': lifetimeEarned.toJson(),
  };
}

/// Complete, immutable game state. Everything but [meta] resets on IPO;
/// moving to a new location resets the location-level fields.
class GameState {
  const GameState({
    required this.cash,
    required this.totalEarned,
    required this.lines,
    this.locationIndex = 0,
    BigNumber? locationEarned,
    this.managers = const {},
    this.upgrades = const {},
    this.powerLevel = 0,
    this.coolingLevel = 0,
    this.playSeconds = 0,
    this.manualJobs = 0,
    this.contractIndex = 0,
    this.boost,
    this.contract,
    this.meta = const MetaState(),
  }) : locationEarned = locationEarned ?? totalEarned;

  /// A fresh run in the first location.
  factory GameState.initial(
    EconomyConfig config, {
    MetaState meta = const MetaState(),
  }) => GameState(
    cash: config.startingCash,
    totalEarned: BigNumber.zero,
    lines: freshLines(config.locations.first),
    meta: meta,
  );

  /// Restores a state, matching saved lines to the location by id so that
  /// lines added to the config later start fresh instead of breaking saves.
  factory GameState.fromJson(Map<String, Object?> json, EconomyConfig config) {
    final locationIndex = ((json['locationIndex'] as num?)?.toInt() ?? 0).clamp(
      0,
      config.locations.length - 1,
    );
    final location = config.locations[locationIndex];
    final savedLines = json['lines']! as Map<String, Object?>;
    final boost = json['boost'] as Map<String, Object?>?;
    final contract = json['contract'] as Map<String, Object?>?;
    return GameState(
      cash: BigNumber.parse(json['cash']! as String),
      totalEarned: BigNumber.parse(json['totalEarned']! as String),
      locationIndex: locationIndex,
      locationEarned: BigNumber.parse(json['locationEarned']! as String),
      lines: [
        for (final l in location.lines)
          savedLines[l.id] == null
              ? LineState(level: l.startLevel)
              : LineState.fromJson(savedLines[l.id]! as Map<String, Object?>),
      ],
      managers: (json['managers']! as List<Object?>).cast<String>().toSet(),
      upgrades: (json['upgrades']! as List<Object?>).cast<String>().toSet(),
      powerLevel: (json['powerLevel']! as num).toInt(),
      coolingLevel: (json['coolingLevel']! as num).toInt(),
      playSeconds: (json['playSeconds']! as num).toDouble(),
      manualJobs: (json['manualJobs']! as num).toInt(),
      contractIndex: (json['contractIndex']! as num).toInt(),
      boost: boost == null ? null : Boost.fromJson(boost),
      contract: contract == null ? null : ContractState.fromJson(contract),
      meta: MetaState.fromJson(json['meta']! as Map<String, Object?>),
    );
  }

  static List<LineState> freshLines(LocationConfig location) => [
    for (final l in location.lines) LineState(level: l.startLevel),
  ];

  final BigNumber cash;

  /// Everything earned this run (across locations); drives IPO shares.
  final BigNumber totalEarned;

  final int locationIndex;

  /// Earned since arriving at the current location; drives its goal.
  final BigNumber locationEarned;

  /// Same order as the current location's lines.
  final List<LineState> lines;

  /// Ids of hired managers (current location).
  final Set<String> managers;

  /// Ids of bought income upgrades (current location).
  final Set<String> upgrades;
  final int powerLevel;
  final int coolingLevel;

  /// Active play time this run, in seconds.
  final double playSeconds;

  /// Jobs completed by tapping, for quests.
  final int manualJobs;

  /// Number of contracts completed this run; seeds the next contract.
  final int contractIndex;

  /// Active temporary income boost, if any.
  final Boost? boost;

  /// The issued contract, if any (see `ContractBook`).
  final ContractState? contract;

  final MetaState meta;

  GameState copyWith({
    BigNumber? cash,
    BigNumber? totalEarned,
    int? locationIndex,
    BigNumber? locationEarned,
    List<LineState>? lines,
    Set<String>? managers,
    Set<String>? upgrades,
    int? powerLevel,
    int? coolingLevel,
    double? playSeconds,
    int? manualJobs,
    int? contractIndex,
    Boost? boost,
    bool clearBoost = false,
    ContractState? contract,
    bool clearContract = false,
    MetaState? meta,
  }) => GameState(
    cash: cash ?? this.cash,
    totalEarned: totalEarned ?? this.totalEarned,
    locationIndex: locationIndex ?? this.locationIndex,
    locationEarned: locationEarned ?? this.locationEarned,
    lines: lines ?? this.lines,
    managers: managers ?? this.managers,
    upgrades: upgrades ?? this.upgrades,
    powerLevel: powerLevel ?? this.powerLevel,
    coolingLevel: coolingLevel ?? this.coolingLevel,
    playSeconds: playSeconds ?? this.playSeconds,
    manualJobs: manualJobs ?? this.manualJobs,
    contractIndex: contractIndex ?? this.contractIndex,
    boost: clearBoost ? null : (boost ?? this.boost),
    contract: clearContract ? null : (contract ?? this.contract),
    meta: meta ?? this.meta,
  );

  GameState withLine(int index, LineState line) =>
      copyWith(lines: [...lines]..[index] = line);

  /// Adds earnings to cash and every earnings counter.
  GameState earn(BigNumber amount) => copyWith(
    cash: cash + amount,
    totalEarned: totalEarned + amount,
    locationEarned: locationEarned + amount,
    meta: meta.copyWith(lifetimeEarned: meta.lifetimeEarned + amount),
  );

  Map<String, Object?> toJson(EconomyConfig config) {
    final location = config.locations[locationIndex];
    return {
      'cash': cash.toJson(),
      'totalEarned': totalEarned.toJson(),
      'locationIndex': locationIndex,
      'locationEarned': locationEarned.toJson(),
      'lines': {
        for (var i = 0; i < lines.length; i++)
          location.lines[i].id: lines[i].toJson(),
      },
      'managers': managers.toList()..sort(),
      'upgrades': upgrades.toList()..sort(),
      'powerLevel': powerLevel,
      'coolingLevel': coolingLevel,
      'playSeconds': playSeconds,
      'manualJobs': manualJobs,
      'contractIndex': contractIndex,
      'boost': boost?.toJson(),
      'contract': contract?.toJson(),
      'meta': meta.toJson(),
    };
  }
}
