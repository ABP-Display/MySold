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
    child: RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              () => TapGestureRecognizer(),
              (instance) => instance
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                ..onTapUp = (details) {
                  widget.onSelect(details.localPosition);
                }
                ..onTapCancel = widget.onClear,
            ),
        _ChartHorizontalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<
              _ChartHorizontalDragRecognizer
            >(
              () => _ChartHorizontalDragRecognizer(),
              (instance) => instance
                ..gestureSettings = MediaQuery.maybeGestureSettingsOf(context)
                ..dragStartBehavior = DragStartBehavior.down
                ..onlyAcceptDragOnThreshold = true
                ..onStart = (details) {
                  _dragKind = details.kind;
                  widget.onSelect(details.localPosition);
                }
                ..onUpdate = (details) {
                  widget.onSelect(details.localPosition);
                }
                ..onEnd = (_) {
                  if (_dragKind != PointerDeviceKind.mouse)
                    widget.onClear?.call();
                  _dragKind = null;
                }
                ..onCancel = () {
                  _dragKind = null;
                  widget.onClear?.call();
                },
            ),
      },
      child: widget.child,
    ),
  );
}

/// A coalesced move can cross both axis thresholds in one event. Let the
/// vertical page recognizer win when that first movement is mostly vertical.
class _ChartHorizontalDragRecognizer extends HorizontalDragGestureRecognizer {
  final _movement = <int, Offset>{};
  Offset _currentMovement = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _movement[event.pointer] = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void addAllowedPointerPanZoom(PointerPanZoomStartEvent event) {
    _movement[event.pointer] = Offset.zero;
    super.addAllowedPointerPanZoom(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final delta = switch (event) {
      PointerMoveEvent() => event.delta,
      PointerPanZoomUpdateEvent() => event.panDelta,
      _ => null,
    };
    if (delta != null && _movement.containsKey(event.pointer)) {
      _currentMovement = _movement[event.pointer]! + delta;
      _movement[event.pointer] = _currentMovement;
    }
    super.handleEvent(event);
    if (event is PointerUpEvent ||
        event is PointerCancelEvent ||
        event is PointerPanZoomEndEvent) {
      _movement.remove(event.pointer);
      if (_movement.isEmpty) _currentMovement = Offset.zero;
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    super.didStopTrackingLastPointer(pointer);
    _movement.clear();
    _currentMovement = Offset.zero;
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      _currentMovement.dx.abs() > _currentMovement.dy.abs() &&
      super.hasSufficientGlobalDistanceToAccept(
        pointerDeviceKind,
        deviceTouchSlop,
      );
}
