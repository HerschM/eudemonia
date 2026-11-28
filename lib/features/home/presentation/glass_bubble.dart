import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Height of every bubble of the shell's bottom row.
const double glassBubbleHeight = 52.0;

/// One translucent, glass-like bubble: clipped to a round / obround shape, a blur of whatever
/// scrolls behind it, a translucent surface colour and a hairline light border. The blur lives
/// only inside the bubble (never a full-width layer), so scrolling stays cheap. With [solidTint]
/// the bubble is an opaque tint instead (no blur is drawn behind it).
///
/// Round when given a [width] of [glassBubbleHeight]; otherwise as wide as its parent allows.
/// [label] is what screen readers say and, for a tappable bubble, the tooltip.
class GlassBubble extends StatelessWidget {
  final Widget child;
  final String label;
  final VoidCallback? onTap;
  final double? width;
  final Color? solidTint;
  final Color? borderColor;
  final AlignmentGeometry alignment;

  const GlassBubble({
    super.key,
    required this.child,
    required this.label,
    this.onTap,
    this.width,
    this.solidTint,
    this.borderColor,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(glassBubbleHeight / 2);
    Widget bubble = DecoratedBox(
      decoration: BoxDecoration(
        color: solidTint ?? AppColors.surface.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.14), width: 1.0),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Align(alignment: alignment, child: child),
        ),
      ),
    );
    if (solidTint == null) {
      bubble = BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: bubble);
    }
    bubble = ClipRRect(borderRadius: radius, child: bubble);
    if (onTap != null) bubble = Tooltip(message: label, excludeFromSemantics: true, child: bubble);
    return Semantics(
      container: true,
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: SizedBox(width: width, height: glassBubbleHeight, child: bubble),
    );
  }
}
