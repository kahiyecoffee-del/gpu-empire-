import 'dart:math' as math;

/// A number of arbitrary magnitude, stored as `mantissa * 10^exponent`.
///
/// Idle games pass 1e308 (the double limit) long before the late game, so all
/// currency math goes through this type. Precision is that of a double
/// (~15 significant digits), which is plenty for display and balancing.
///
/// Invariant: either the value is zero (`mantissa == 0`, `exponent == 0`) or
/// `1 <= mantissa.abs() < 10`.
class BigNumber implements Comparable<BigNumber> {
  const BigNumber._(this.mantissa, this.exponent);

  /// Builds a normalized number from any mantissa/exponent pair.
  factory BigNumber.fromParts(double mantissa, int exponent) =>
      _normalize(mantissa, exponent);

  factory BigNumber.from(num value) => _normalize(value.toDouble(), 0);

  /// Builds `10^log10Value`. Useful for powers whose result exceeds a double.
  factory BigNumber.fromLog10(double log10Value) {
    if (log10Value == double.negativeInfinity) return zero;
    if (!log10Value.isFinite) {
      throw ArgumentError.value(log10Value, 'log10Value', 'must be finite');
    }
    final exp = log10Value.floor();
    return _normalize(math.pow(10.0, log10Value - exp).toDouble(), exp);
  }

  /// Parses the format produced by [toJson].
  factory BigNumber.parse(String source) {
    final index = source.indexOf('e');
    if (index < 0) return BigNumber.from(double.parse(source));
    return BigNumber.fromParts(
      double.parse(source.substring(0, index)),
      int.parse(source.substring(index + 1)),
    );
  }

  static const zero = BigNumber._(0, 0);
  static const one = BigNumber._(1, 0);

  /// Beyond this exponent gap, the smaller operand is below double precision
  /// and does not change a sum.
  static const _precisionDigits = 17;

  final double mantissa;
  final int exponent;

  bool get isZero => mantissa == 0;
  bool get isNegative => mantissa < 0;

  static BigNumber _normalize(double mantissa, int exponent) {
    if (mantissa.isNaN || mantissa.isInfinite) {
      throw ArgumentError.value(mantissa, 'mantissa', 'must be finite');
    }
    if (mantissa == 0) return zero;
    var m = mantissa;
    var e = exponent;
    final shift = (math.log(m.abs()) / math.ln10).floor();
    if (shift != 0) {
      m = m / math.pow(10.0, shift);
      e += shift;
    }
    // Floating point can leave the mantissa just outside [1, 10).
    if (m.abs() >= 10) {
      m /= 10;
      e += 1;
    } else if (m.abs() < 1) {
      m *= 10;
      e -= 1;
    }
    return BigNumber._(m, e);
  }

  BigNumber operator +(BigNumber other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final (big, small) = exponent >= other.exponent
        ? (this, other)
        : (other, this);
    final gap = big.exponent - small.exponent;
    if (gap > _precisionDigits) return big;
    return _normalize(
      big.mantissa + small.mantissa / math.pow(10.0, gap),
      big.exponent,
    );
  }

  BigNumber operator -(BigNumber other) => this + -other;

  BigNumber operator -() => BigNumber._(-mantissa, exponent);

  BigNumber operator *(BigNumber other) {
    if (isZero || other.isZero) return zero;
    return _normalize(mantissa * other.mantissa, exponent + other.exponent);
  }

  BigNumber operator /(BigNumber other) {
    if (other.isZero) throw ArgumentError('Division by zero');
    if (isZero) return zero;
    return _normalize(mantissa / other.mantissa, exponent - other.exponent);
  }

  /// Multiplies by a plain double.
  BigNumber scale(double factor) => this * BigNumber.from(factor);

  /// Raises a non-negative number to [power].
  BigNumber pow(double power) {
    if (isNegative) throw ArgumentError('pow of a negative BigNumber');
    if (isZero) return power == 0 ? one : zero;
    final log = log10() * power;
    // Inside double range, direct pow is exact for cases like 4^0.5 where
    // the log route would give 1.9999999.
    if (exponent.abs() < 300 && log.abs() < 300) {
      return BigNumber.from(math.pow(toDouble(), power));
    }
    return BigNumber.fromLog10(log);
  }

  /// Base-10 logarithm. Negative infinity for zero.
  double log10() {
    if (isZero) return double.negativeInfinity;
    return exponent + math.log(mantissa.abs()) / math.ln10;
  }

  /// Largest integer not greater than this number.
  BigNumber floor() {
    // Above 2^53 every double is already an integer.
    if (exponent >= 16) return this;
    return BigNumber.from(toDouble().floorToDouble());
  }

  BigNumber max(BigNumber other) => this >= other ? this : other;
  BigNumber min(BigNumber other) => this <= other ? this : other;

  /// Converts to a double. Returns infinity when out of double range.
  double toDouble() {
    if (exponent > 308) return mantissa.sign * double.infinity;
    if (exponent < -324) return 0;
    return mantissa * math.pow(10.0, exponent);
  }

  @override
  int compareTo(BigNumber other) {
    final signA = mantissa.sign;
    final signB = other.mantissa.sign;
    if (signA != signB) return signA.compareTo(signB);
    if (signA == 0) return 0;
    // Same sign: a larger exponent means a larger magnitude.
    final magnitude = exponent != other.exponent
        ? exponent.compareTo(other.exponent)
        : mantissa.abs().compareTo(other.mantissa.abs());
    return signA > 0 ? magnitude : -magnitude;
  }

  bool operator <(BigNumber other) => compareTo(other) < 0;
  bool operator <=(BigNumber other) => compareTo(other) <= 0;
  bool operator >(BigNumber other) => compareTo(other) > 0;
  bool operator >=(BigNumber other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is BigNumber &&
      other.mantissa == mantissa &&
      other.exponent == exponent;

  @override
  int get hashCode => Object.hash(mantissa, exponent);

  /// Compact lossless string form, e.g. `1.5e42`.
  String toJson() => '${mantissa}e$exponent';

  @override
  String toString() => toJson();
}
