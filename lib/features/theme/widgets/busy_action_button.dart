import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/thinking_indicator.dart';

/// A filled action button that, while [busy], is disabled and shows a [ThinkingIndicator] with
/// [busyLabel] in the same place and at the same size, so nothing around it moves. The button is
/// as wide as the wider of its two faces, measured from the labels (only the face in use is built,
/// so an idle button runs no animation). Pure presentational widget.
class BusyActionButton extends StatelessWidget {
  static const _iconSize = 13.0;

  final String label;
  final String busyLabel;
  final IconData? icon;
  final bool busy;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final double fontSize;

  const BusyActionButton({
    super.key,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.radius = 6,
    this.color = AppColors.accentAction,
    this.fontSize = 11,
  });

  /// Width the text of [text] takes at the button's font size and the user's text scale.
  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final textStyle = TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: Colors.white);
    final measureStyle = DefaultTextStyle.of(context).style.merge(textStyle);
    final idleWidth = (icon != null ? _iconSize + 4 : 0) + _textWidth(context, label, measureStyle);
    // The spark and its gap, then the label.
    final busyWidth = _iconSize + 6 + _textWidth(context, busyLabel, measureStyle);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: busy ? null : onPressed,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: busy ? AppColors.accentAI.withValues(alpha: 0.14) : color,
            borderRadius: borderRadius,
            border: Border.all(color: busy ? AppColors.accentAI.withValues(alpha: 0.35) : Colors.transparent),
          ),
          // At least as wide as the wider face, so the swap does not move anything around it.
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: (idleWidth > busyWidth ? idleWidth : busyWidth).ceilToDouble() + 1),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: busy
                  ? ThinkingIndicator(label: busyLabel, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: _iconSize, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        // May wrap on a very narrow screen instead of overflowing.
                        Flexible(child: Text(label, style: textStyle)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
