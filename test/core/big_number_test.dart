import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';

BigNumber b(num v) => BigNumber.from(v);

void main() {
  group('normalization', () {
    test('keeps mantissa in [1, 10)', () {
      final n = b(12345);
      expect(n.mantissa, closeTo(1.2345, 1e-12));
      expect(n.exponent, 4);
    });

    test('handles small and negative values', () {
      expect(b(0.05).exponent, -2);
      expect(b(-250).mantissa, closeTo(-2.5, 1e-12));
      expect(b(-250).exponent, 2);
    });

    test('zero is canonical', () {
      expect(b(0), BigNumber.zero);
      expect(BigNumber.fromParts(0, 99), BigNumber.zero);
      expect(BigNumber.zero.isZero, isTrue);
    });

    test('values beyond 2^63 do not overflow', () {
      // Regression: powers of ten were once computed with int math.
      final n = b(5.6e19);
      expect(n.exponent, 19);
      expect(n.mantissa, closeTo(5.6, 1e-12));
      expect(n > b(1e4), isTrue);
    });

    test('rejects non-finite input', () {
      expect(() => b(double.infinity), throwsArgumentError);
      expect(() => b(double.nan), throwsArgumentError);
    });
  });

  group('arithmetic', () {
    test('add and subtract', () {
      expect((b(60) + b(4.28)).toDouble(), closeTo(64.28, 1e-9));
      expect((b(60) - b(4.28)).toDouble(), closeTo(55.72, 1e-9));
      expect((b(5) - b(5)).isZero, isTrue);
      expect((b(1) - b(3)).toDouble(), closeTo(-2, 1e-12));
    });

    test('adding a much smaller number is a no-op', () {
      final big = BigNumber.fromParts(1, 100);
      expect(big + b(1), big);
    });

    test('multiply and divide across huge exponents', () {
      final x = BigNumber.fromParts(3, 200);
      final y = BigNumber.fromParts(4, 250);
      final product = x * y;
      expect(product.mantissa, closeTo(1.2, 1e-12));
      expect(product.exponent, 451);
      final quotient = product / y;
      expect(quotient.mantissa, closeTo(3, 1e-12));
      expect(quotient.exponent, 200);
    });

    test('division by zero throws', () {
      expect(() => b(1) / BigNumber.zero, throwsArgumentError);
    });

    test('pow and log10', () {
      expect(b(1000).log10(), closeTo(3, 1e-12));
      final p = b(10).pow(500);
      expect(p.exponent, 500);
      expect(p.mantissa, closeTo(1, 1e-9));
      expect(b(4).pow(0.5).toDouble(), closeTo(2, 1e-12));
      expect(BigNumber.zero.pow(2), BigNumber.zero);
    });

    test('fromLog10 builds powers beyond double range', () {
      final n = BigNumber.fromLog10(400.30103);
      expect(n.exponent, 400);
      expect(n.mantissa, closeTo(2, 1e-4));
    });

    test('floor', () {
      expect(b(4.99).floor().toDouble(), 4);
      final huge = BigNumber.fromParts(1.5, 40);
      expect(huge.floor(), huge);
    });
  });

  group('comparison', () {
    test('orders by sign, exponent, then mantissa', () {
      final values = [b(-1e10), b(-5), BigNumber.zero, b(0.5), b(9), b(10)]
        ..shuffle();
      values.sort();
      expect(values.map((v) => v.toDouble()), [-1e10, -5, 0, 0.5, 9, 10]);
    });

    test('operators', () {
      expect(b(2) < b(3), isTrue);
      expect(b(3) <= b(3), isTrue);
      expect(BigNumber.fromParts(1, 300) > BigNumber.fromParts(9, 299), isTrue);
      expect(b(-2) > b(-3), isTrue);
      expect(b(5).max(b(7)), b(7));
      expect(b(5).min(b(7)), b(5));
    });
  });

  group('serialization', () {
    test('round trips through toJson and parse', () {
      for (final n in [
        BigNumber.zero,
        b(4.28),
        b(-1234.5),
        BigNumber.fromParts(7.25, 1234),
      ]) {
        expect(BigNumber.parse(n.toJson()), n);
      }
    });

    test('parse accepts plain numbers', () {
      expect(BigNumber.parse('1500').toDouble(), 1500);
    });

    test('toDouble saturates outside double range', () {
      expect(BigNumber.fromParts(1, 400).toDouble(), double.infinity);
    });
  });
}
