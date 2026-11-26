import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// The "not yet seen" dot of a card. While [unread] it is a solid dot; when [unread] turns false
/// it dissolves like smoke (about 700 ms: it grows to twice its size while it blurs and fades).
/// The slot keeps its size once the dot has been shown, so the header around it never shifts.
/// A card that is read from the start takes no space. Static (no dissolve) when the system asks
/// for no animation. Pure presentational widget.
class UnreadDot extends StatefulWidget {
  final bool unread;
  final double size;
  final Color color;

  /// Space before the dot, kept together with the slot.
  final EdgeInsetsGeometry margin;

  /// Key of the painted dot: present while the dot is shown or dissolving, absent afterwards.
  final Key? dotKey;

  const UnreadDot({
    super.key,
    required this.unread,
    this.size = 8,
    this.color = AppColors.unreadDot,
    this.margin = EdgeInsets.zero,
    this.dotKey,
  });

  static const dissolveDuration = Duration(milliseconds: 700);

  @override
  State<UnreadDot> createState() => _UnreadDotState();
}

class _UnreadDotState extends State<UnreadDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: UnreadDot.dissolveDuration);

  /// The dot has been shown, so its slot stays reserved.
  late bool _reserved = widget.unread;
  bool _dissolving = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() => _dissolving = false);
    });
  }

  @override
  void didUpdateWidget(covariant UnreadDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unread) {
      _reserved = true;
      if (_dissolving || _controller.value != 0) {
        _dissolving = false;
        _controller.value = 0;
      }
    } else if (oldWidget.unread && !_dissolving) {
      if (MediaQuery.disableAnimationsOf(context)) return;
      _dissolving = true;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_reserved) return const SizedBox.shrink();
    final Widget dot;
    if (widget.unread) {
      dot = DecoratedBox(
        key: widget.dotKey,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    } else if (_dissolving) {
      dot = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          key: widget.dotKey,
          painter: _DissolvePainter(progress: _controller.value, color: widget.color),
        ),
      );
    } else {
      dot = const SizedBox.shrink();
    }
    return Padding(
      padding: widget.margin,
      // The layout box never changes; the dissolving dot paints outside of it.
      child: SizedBox(width: widget.size, height: widget.size, child: dot),
    );
  }
}

/// A dot that grows to twice its size while it blurs and fades out.
class _DissolvePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _DissolvePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final eased = Curves.easeOut.transform(progress);
    final fade = 1.0 - Curves.easeIn.transform(progress);
    final paint = Paint()..color = color.withValues(alpha: color.a * fade);
    final sigma = eased * 3.0;
    if (sigma > 0.01) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);
    canvas.drawCircle(size.center(Offset.zero), size.width / 2 * (1 + eased), paint);
  }

  @override
  bool shouldRepaint(covariant _DissolvePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
