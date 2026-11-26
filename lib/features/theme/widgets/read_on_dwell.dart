import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Calls [onRead] once its [child] (an unread card) has stayed on screen for [dwell]: at least
/// [minVisible] of its height inside the viewport of the nearest scrollable, without a break,
/// while [active] (its tab is the selected one) and the app is resumed. Scrolling is a break.
///
/// Cheap by design: while [enabled] is false (the card is already read) the widget holds no
/// timer and no listeners; while true it holds at most one [Timer], started when the card is
/// seen to be visible enough (first layout, scroll end, size change, tab or app state change)
/// and cancelled as soon as it is not, or when the widget goes away. The timer re-checks the
/// visibility when it fires. A card taller than the viewport counts as seen once it fills
/// [minVisible] of the viewport instead. Pure presentational widget.
class ReadOnDwell extends StatefulWidget {
  final Widget child;
  final VoidCallback onRead;
  final bool enabled;
  final bool active;
  final Duration dwell;
  final double minVisible;

  const ReadOnDwell({
    super.key,
    required this.child,
    required this.onRead,
    this.enabled = true,
    this.active = true,
    this.dwell = const Duration(seconds: 3),
    this.minVisible = 0.6,
  });

  @override
  State<ReadOnDwell> createState() => _ReadOnDwellState();
}

class _ReadOnDwellState extends State<ReadOnDwell> with WidgetsBindingObserver {
  Timer? _timer;
  ScrollPosition? _position;
  bool _resumed = true;
  bool _fired = false;
  bool _checkScheduled = false;

  bool get _shouldWatch => widget.enabled && widget.active && _resumed && !_fired;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _resumed = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _scheduleCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _detachPosition();
      _position = position;
      position?.isScrollingNotifier.addListener(_onScrollingChanged);
      position?.addListener(_onPositionChanged);
      _scheduleCheck();
    }
  }

  @override
  void didUpdateWidget(covariant ReadOnDwell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A card that turns unread again (or was never read) can be read once more.
    if (widget.enabled && !oldWidget.enabled) _fired = false;
    if (widget.enabled != oldWidget.enabled || widget.active != oldWidget.active) _scheduleCheck();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _scheduleCheck();
  }

  @override
  void didChangeMetrics() => _scheduleCheck();

  void _onScrollingChanged() => _scheduleCheck();

  /// A jump of the scroll position (not a drag or fling, which [_onScrollingChanged] covers).
  void _onPositionChanged() {
    if (!(_position?.isScrollingNotifier.value ?? false)) _scheduleCheck();
  }

  void _detachPosition() {
    _position?.isScrollingNotifier.removeListener(_onScrollingChanged);
    _position?.removeListener(_onPositionChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachPosition();
    _timer?.cancel();
    super.dispose();
  }

  /// Looks again once the current frame has been laid out.
  void _scheduleCheck() {
    if (_checkScheduled) return;
    if (!_shouldWatch) {
      _cancel();
      return;
    }
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _check();
    });
    // Scroll end and similar changes happen between frames; make sure one comes.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _check() {
    if (_isSeen()) {
      // A running timer means the card has been seen without a break so far: let it run.
      _timer ??= Timer(widget.dwell, _onElapsed);
    } else {
      _cancel();
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _onElapsed() {
    _timer = null;
    if (!mounted || !_isSeen()) return;
    _fired = true;
    widget.onRead();
  }

  bool _isSeen() {
    if (!_shouldWatch || (_position?.isScrollingNotifier.value ?? false)) return false;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize || box.size.height <= 0) return false;
    final viewportObject = RenderAbstractViewport.maybeOf(box);
    if (viewportObject is! RenderBox) return false;
    final viewport = viewportObject as RenderBox;
    if (!viewport.hasSize) return false;
    final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final visible = math.min(top + box.size.height, viewport.size.height) - math.max(top, 0.0);
    final needed = widget.minVisible * math.min(box.size.height, viewport.size.height);
    return visible >= needed - 0.01;
  }

  @override
  Widget build(BuildContext context) {
    // The card changing its own size (text edited, notes expanded) changes how much of it is seen.
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleCheck();
        return false;
      },
      child: SizeChangedLayoutNotifier(child: widget.child),
    );
  }
}
