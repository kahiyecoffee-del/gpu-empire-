import 'package:flutter/material.dart';

/// Visual identity of each production line: its accent color drives the
/// rack art, card tint and glows. Kept in the UI layer, keyed by line id.
class LineStyle {
  const LineStyle({required this.body, required this.led, required this.glow});

  /// Main color of the rack casing.
  final Color body;

  /// LED color on the rack front.
  final Color led;

  /// Accent used for card tints, progress bars and highlights.
  final Color glow;

  static const _fallback = LineStyle(
    body: Color(0xFF4A5578),
    led: Color(0xFF3DDC97),
    glow: Color(0xFF3DDC97),
  );

  static const _styles = {
    'legacy_gpu': LineStyle(
      body: Color(0xFF5B6478),
      led: Color(0xFF7CF29A),
      glow: Color(0xFF3DDC97),
    ),
    'gaming_cluster': LineStyle(
      body: Color(0xFF4B2E83),
      led: Color(0xFFFF4FD8),
      glow: Color(0xFFB65CFF),
    ),
    'datacenter_gpu': LineStyle(
      body: Color(0xFF1F4E8C),
      led: Color(0xFF5CC8FF),
      glow: Color(0xFF4DA3FF),
    ),
    'tpu_pod': LineStyle(
      body: Color(0xFF8A4B14),
      led: Color(0xFFFFC44D),
      glow: Color(0xFFFF9F2E),
    ),
    'supercomputer': LineStyle(
      body: Color(0xFF0F5E66),
      led: Color(0xFF5FFFF0),
      glow: Color(0xFF29E0D0),
    ),
    'quantum': LineStyle(
      body: Color(0xFF5A1660),
      led: Color(0xFFFF7BF2),
      glow: Color(0xFFFF5CC8),
    ),
  };

  static LineStyle of(String lineId) => _styles[lineId] ?? _fallback;
}
