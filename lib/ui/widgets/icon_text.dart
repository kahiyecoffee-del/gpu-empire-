import 'package:flutter/material.dart';

/// Text with a leading icon that scales with the font size.
///
/// Uses the bundled Material icons instead of emoji, which would need a
/// color emoji font downloaded at runtime on the web.
class IconText extends StatelessWidget {
  const IconText(
    this.icon,
    this.text, {
    super.key,
    this.style,
    this.iconColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final IconData icon;
  final String text;
  final TextStyle? style;
  final Color? iconColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final effective = DefaultTextStyle.of(context).style.merge(style);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                icon,
                size: (effective.fontSize ?? 14) * 1.2,
                color: iconColor ?? effective.color,
              ),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
