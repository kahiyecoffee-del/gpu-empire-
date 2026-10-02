import 'package:flutter/material.dart';

/// Shows short-lived labels (like `+$1.2K`) that float up and fade out.
/// Call [FloatingGainsState.spawn] through a GlobalKey.
class FloatingGains extends StatefulWidget {
  const FloatingGains({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  State<FloatingGains> createState() => FloatingGainsState();
}

class FloatingGainsState extends State<FloatingGains>
    with TickerProviderStateMixin {
  /// More than this many labels at once is just noise.
  static const _maxLabels = 4;

  final List<(String, AnimationController)> _labels = [];

  void spawn(String text) {
    if (!mounted || _labels.length >= _maxLabels) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final entry = (text, controller);
    setState(() => _labels.add(entry));
    controller.forward().whenComplete(() {
      controller.dispose();
      if (mounted) setState(() => _labels.remove(entry));
    });
  }

  @override
  void dispose() {
    for (final (_, c) in _labels) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        for (final (text, controller) in _labels)
          Positioned(
            left: 8,
            top: 0,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  final t = Curves.easeOut.transform(controller.value);
                  return Opacity(
                    opacity: (1 - controller.value).clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 10 - 36 * t),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          shadows: [
                            Shadow(color: widget.color, blurRadius: 10),
                            const Shadow(color: Colors.black, blurRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
