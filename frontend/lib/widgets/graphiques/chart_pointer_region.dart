import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// The horizontal recognizer competes with the page's vertical recognizer.
/// Once either direction wins, small finger drift cannot switch ownership.
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
  PointerDeviceKind? _dragKind;
  ScrollPosition? _position;
  double? _lastPixels;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (_position != position) {
      _position?.removeListener(_onScroll);
      _position = position;
      _lastPixels = position?.pixels;
      _position?.addListener(_onScroll);
    }
  }

  void _onScroll() {
    final position = _position;
    if (position == null ||
        position.axis != Axis.vertical ||
        position.pixels == _lastPixels)
      return;
    _lastPixels = position.pixels;
    widget.onClear?.call();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  bool get _scrolling =>
      Scrollable.maybeOf(context)?.position.isScrollingNotifier.value ?? false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.cursor,
    onExit: (_) => widget.onClear?.call(),
    onHover: (event) {
      if (!_scrolling) widget.onSelect(event.localPosition);
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      dragStartBehavior: DragStartBehavior.down,
      onTapUp: (details) => widget.onSelect(details.localPosition),
      onTapCancel: widget.onClear,
      onHorizontalDragStart: (details) {
        _dragKind = details.kind;
        widget.onSelect(details.localPosition);
      },
      onHorizontalDragUpdate: (details) =>
          widget.onSelect(details.localPosition),
      onHorizontalDragEnd: (_) {
        if (_dragKind != PointerDeviceKind.mouse) widget.onClear?.call();
        _dragKind = null;
      },
      onHorizontalDragCancel: () {
        _dragKind = null;
        widget.onClear?.call();
      },
      child: widget.child,
    ),
  );
}
