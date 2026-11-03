import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Observe chart selection without competing with the page's scroll gesture.
/// A vertical drag belongs to the page and must not rebuild chart tooltips.
class ChartPointerRegion extends StatefulWidget {
  final Widget child;
  final ValueChanged<Offset> onSelect;
  final VoidCallback? onClear;
  final MouseCursor cursor;
  const ChartPointerRegion({
    super.key,
    required this.child,
    required this.onSelect,
    this.onClear,
    this.cursor = SystemMouseCursors.precise,
  });

  @override
  State<ChartPointerRegion> createState() => _ChartPointerRegionState();
}

class _ChartPointerRegionState extends State<ChartPointerRegion> {
  Offset? _origin;
  int? _pointer;
  bool _verticalDrag = false;

  bool get _scrolling =>
      Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ?? false;

  void _clear() {
    _origin = null;
    _pointer = null;
    _verticalDrag = false;
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onExit: (_) => _clear(),
    onHover: (event) {
      if (!_scrolling) widget.onSelect(event.localPosition);
    },
    child: Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        _pointer = event.pointer;
        _origin = event.position;
        _verticalDrag = false;
        if (!_scrolling) widget.onSelect(event.localPosition);
      },
      onPointerMove: (event) {
        if (_pointer != event.pointer || _origin == null) return;
        final movement = event.position - _origin!;
        if (!_verticalDrag &&
            movement.dy.abs() > kTouchSlop &&
            movement.dy.abs() > movement.dx.abs()) {
          _verticalDrag = true;
          widget.onClear?.call();
        }
        if (!_verticalDrag) {
          widget.onSelect(event.localPosition);
        }
      },
      onPointerUp: (event) {
        if (_pointer != event.pointer) return;
        _pointer = null;
        _origin = null;
        if (event.kind != PointerDeviceKind.mouse) _clear();
      },
      onPointerCancel: (_) => _clear(),
      child: widget.child,
    ),
  );
}
