import 'dart:math' as math;

import 'big_number.dart';

const _namedSuffixes = ['', 'K', 'M', 'B', 'T'];
const _alphabet = 'abcdefghijklmnopqrstuvwxyz';

/// Suffix for a power-of-1000 tier: '', K, M, B, T, then aa, ab, ... zz, aaa.
String suffixForTier(int tier) {
  if (tier < 0) throw ArgumentError.value(tier, 'tier', 'must be >= 0');
  if (tier < _namedSuffixes.length) return _namedSuffixes[tier];
  var n = tier - _namedSuffixes.length;
  // Letter codes of length 2 cover 676 tiers, then length 3, and so on.
  var length = 2;
  var block = 26 * 26;
  while (n >= block) {
    n -= block;
    length++;
    block *= 26;
  }
  final letters = List.filled(length, 'a');
  for (var i = length - 1; i >= 0; i--) {
    letters[i] = _alphabet[n % 26];
    n ~/= 26;
  }
  return letters.join();
}

/// Short display form: `999`, `4.28`, `1.23K`, `45.6M`, `789aa`.
///
/// Values are truncated, never rounded up, so the display never claims the
/// player has more than they do.
String formatBig(BigNumber value) {
  if (value.isNegative) return '-${formatBig(-value)}';
  if (value.exponent < 3) {
    final v = value.toDouble();
    if (v >= 100) return v.floor().toString();
    return _trimZeros(_truncate(v, 2));
  }
  final tier = value.exponent ~/ 3;
  final scaled = value.mantissa * math.pow(10.0, value.exponent % 3);
  final decimals = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2);
  return '${_truncate(scaled, decimals)}${suffixForTier(tier)}';
}

/// Formats a plain double with the same rules as [formatBig].
String formatDouble(double value) => formatBig(BigNumber.from(value));

const _powerUnits = ['kW', 'MW', 'GW', 'TW', 'PW'];

/// Formats a power value given in kW: `850 kW`, `1.20 MW`, `45.6 GW`.
String formatPower(double kW) {
  var value = kW;
  var unit = 0;
  while (value >= 1000 && unit < _powerUnits.length - 1) {
    value /= 1000;
    unit++;
  }
  return '${formatDouble(value)} ${_powerUnits[unit]}';
}

/// Formats a duration in seconds as `45s`, `3m 05s` or `2h 14m`.
String formatDuration(double seconds) {
  final total = seconds.floor();
  if (total < 60) return '${total}s';
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
  return '${m}m ${s.toString().padLeft(2, '0')}s';
}

String _truncate(double value, int decimals) {
  final factor = math.pow(10.0, decimals);
  // The small epsilon absorbs binary representation error (4.28 -> 4.2799..).
  final truncated = (value * factor + 1e-9).floorToDouble() / factor;
  return truncated.toStringAsFixed(decimals);
}

String _trimZeros(String fixed) {
  if (!fixed.contains('.')) return fixed;
  var s = fixed;
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
