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

/// Complete, immutable game state for one run (resets on IPO).
class GameState {
  const GameState({
    required this.cash,
    required this.totalEarned,
    required this.lines,
    this.managers = const {},
    this.upgrades = const {},
    this.powerLevel = 0,
    this.coolingLevel = 0,
    this.playSeconds = 0,
  });

  factory GameState.initial(EconomyConfig config) => GameState(
    cash: config.startingCash,
    totalEarned: BigNumber.zero,
    lines: [for (final l in config.lines) LineState(level: l.startLevel)],
  );

  /// Restores a state, matching saved lines to the config by id so that lines
  /// added to the config later start fresh instead of breaking old saves.
  factory GameState.fromJson(Map<String, Object?> json, EconomyConfig config) {
    final savedLines = json['lines']! as Map<String, Object?>;
    return GameState(
      cash: BigNumber.parse(json['cash']! as String),
      totalEarned: BigNumber.parse(json['totalEarned']! as String),
      lines: [
        for (final l in config.lines)
          savedLines[l.id] == null
              ? LineState(level: l.startLevel)
              : LineState.fromJson(savedLines[l.id]! as Map<String, Object?>),
      ],
      managers: (json['managers']! as List<Object?>).cast<String>().toSet(),
      upgrades: (json['upgrades']! as List<Object?>).cast<String>().toSet(),
      powerLevel: (json['powerLevel']! as num).toInt(),
      coolingLevel: (json['coolingLevel']! as num).toInt(),
      playSeconds: (json['playSeconds']! as num).toDouble(),
    );
  }

  final BigNumber cash;

  /// Everything earned this run; drives the IPO share preview.
  final BigNumber totalEarned;

  /// Same order as [EconomyConfig.lines].
  final List<LineState> lines;

  /// Ids of hired managers.
  final Set<String> managers;

  /// Ids of bought income upgrades.
  final Set<String> upgrades;
  final int powerLevel;
  final int coolingLevel;

  /// Active play time this run, in seconds.
  final double playSeconds;

  GameState copyWith({
    BigNumber? cash,
    BigNumber? totalEarned,
    List<LineState>? lines,
    Set<String>? managers,
    Set<String>? upgrades,
    int? powerLevel,
    int? coolingLevel,
    double? playSeconds,
  }) => GameState(
    cash: cash ?? this.cash,
    totalEarned: totalEarned ?? this.totalEarned,
    lines: lines ?? this.lines,
    managers: managers ?? this.managers,
    upgrades: upgrades ?? this.upgrades,
    powerLevel: powerLevel ?? this.powerLevel,
    coolingLevel: coolingLevel ?? this.coolingLevel,
    playSeconds: playSeconds ?? this.playSeconds,
  );

  GameState withLine(int index, LineState line) =>
      copyWith(lines: [...lines]..[index] = line);

  Map<String, Object?> toJson(EconomyConfig config) => {
    'cash': cash.toJson(),
    'totalEarned': totalEarned.toJson(),
    'lines': {
      for (var i = 0; i < lines.length; i++)
        config.lines[i].id: lines[i].toJson(),
    },
    'managers': managers.toList()..sort(),
    'upgrades': upgrades.toList()..sort(),
    'powerLevel': powerLevel,
    'coolingLevel': coolingLevel,
    'playSeconds': playSeconds,
  };
}
