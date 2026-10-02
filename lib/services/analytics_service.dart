import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Product analytics. Firebase Analytics is connected in Phase 5; until
/// then [DebugAnalyticsService] keeps recent events for the dev menu.
abstract class AnalyticsService {
  Future<void> init();

  void logEvent(String name, Map<String, Object> params);
}

class LoggedEvent {
  const LoggedEvent(this.time, this.name, this.params);

  final DateTime time;
  final String name;
  final Map<String, Object> params;
}

/// Remembers the last [capacity] events in memory.
class DebugAnalyticsService implements AnalyticsService {
  DebugAnalyticsService({this.capacity = 100});

  final int capacity;
  final _events = Queue<LoggedEvent>();

  /// Newest first.
  List<LoggedEvent> get events => _events.toList().reversed.toList();

  @override
  Future<void> init() async {}

  @override
  void logEvent(String name, Map<String, Object> params) {
    _events.addLast(LoggedEvent(DateTime.now(), name, params));
    while (_events.length > capacity) {
      _events.removeFirst();
    }
    if (kDebugMode) debugPrint('analytics: $name $params');
  }
}
