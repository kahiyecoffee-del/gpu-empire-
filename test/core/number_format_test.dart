import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/number_format.dart';

void main() {
  group('suffixForTier', () {
    test('named suffixes then letter codes', () {
      expect(suffixForTier(0), '');
      expect(suffixForTier(1), 'K');
      expect(suffixForTier(4), 'T');
      expect(suffixForTier(5), 'aa');
      expect(suffixForTier(6), 'ab');
      expect(suffixForTier(5 + 25), 'az');
      expect(suffixForTier(5 + 26), 'ba');
      expect(suffixForTier(5 + 675), 'zz');
      expect(suffixForTier(5 + 676), 'aaa');
    });
  });

  group('formatBig', () {
    String f(num v) => formatBig(BigNumber.from(v));

    test('small values', () {
      expect(f(0), '0');
      expect(f(4.28), '4.28');
      expect(f(4.5), '4.5');
      expect(f(35.519), '35.51');
      expect(f(999.9), '999');
    });

    test('three significant digits with suffix', () {
      expect(f(1000), '1.00K');
      expect(f(1234), '1.23K');
      expect(f(45678), '45.6K');
      expect(f(999999), '999K');
      expect(f(1.5e6), '1.50M');
      expect(f(2.5e12), '2.50T');
      expect(f(7.89e17), '789aa');
    });

    test('truncates instead of rounding up', () {
      expect(f(1999), '1.99K');
      expect(f(99999), '99.9K');
    });

    test('negative and astronomically large values', () {
      expect(f(-1500), '-1.50K');
      expect(
        formatBig(BigNumber.fromParts(1, 300)),
        '1.00${suffixForTier(100)}',
      );
    });
  });

  group('formatDuration', () {
    test('formats seconds, minutes and hours', () {
      expect(formatDuration(7.9), '7s');
      expect(formatDuration(185), '3m 05s');
      expect(formatDuration(8040), '2h 14m');
    });
  });
}
