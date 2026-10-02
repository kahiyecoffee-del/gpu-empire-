import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../core/big_number.dart';
import '../../core/number_format.dart';

/// Shows a money value that glides toward its target instead of jumping, so
/// income feels like it is flowing in.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney({super.key, required this.value, this.style});

  final BigNumber value;
  final TextStyle? style;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney>
    with SingleTickerProviderStateMixin {
  /// Fraction of the remaining distance covered per second.
  static const _speed = 8.0;

  late BigNumber _shown = widget.value;
  late final Ticker _ticker = createTicker(_onTick);
  Duration _last = Duration.zero;

  @override
  void didUpdateWidget(AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _shown && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final target = widget.value;
    final diff = target - _shown;
    // Spending drops the counter at once; only gains glide.
    if (diff.isNegative || diff <= target.scale(1e-4)) {
      setState(() => _shown = target);
      _ticker.stop();
      return;
    }
    final step = (dt * _speed).clamp(0.0, 1.0);
    setState(() => _shown = _shown + diff.scale(step));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text('\$${formatBig(_shown)}', style: widget.style);
}
