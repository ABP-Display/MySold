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
  bool _horizontalDrag = false;
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_onScroll);
      _position = position;
      _position?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    if (_position?.axis != Axis.vertical) return;
    if (_pointer != null) _verticalDrag = true;
    widget.onClear?.call();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  bool get _scrolling =>
      Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ?? false;

  void _clear() {
    _origin = null;
    _pointer = null;
    _verticalDrag = false;
    _horizontalDrag = false;
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
        _horizontalDrag = false;
      },
      onPointerMove: (event) {
        if (_pointer != event.pointer || _origin == null) return;
        final movement = event.position - _origin!;
        if (!_verticalDrag && !_horizontalDrag) {
          final slop =
              MediaQuery.gestureSettingsOf(context).touchSlop ?? kTouchSlop;
          if (movement.distance <= slop) return;
          if (movement.dy.abs() >= movement.dx.abs()) {
            _verticalDrag = true;
            widget.onClear?.call();
          } else {
            _horizontalDrag = true;
          }
        }
        if (_horizontalDrag && !_verticalDrag) {
          widget.onSelect(event.localPosition);
        }
      },
      onPointerUp: (event) {
        if (_pointer != event.pointer) return;
        if (!_verticalDrag && !_horizontalDrag) {
          widget.onSelect(event.localPosition);
        } else if (_horizontalDrag && event.kind != PointerDeviceKind.mouse) {
          widget.onClear?.call();
        }
        _pointer = null;
        _origin = null;
        _verticalDrag = false;
        _horizontalDrag = false;
      },
      onPointerCancel: (_) => _clear(),
      child: widget.child,
    ),
  );
}
