import 'dart:math' as math;
import 'chart_pointer_region.dart';
import 'package:flutter/material.dart';

class ChartInfo {
  final String title, detail;
  final Color? color;
  const ChartInfo(this.title, this.detail, {this.color});
}

/// Paint information above the visible viewport, outside any inner chart clip.
/// Raw pointer listeners preserve horizontal chart and vertical page scrolling.
class ChartInfoRegion extends StatefulWidget {
  final Widget child;
  final ChartInfo? Function(Offset position, Size viewport) resolve;
  final Listenable? changes;
  const ChartInfoRegion({
    super.key,
    required this.child,
    required this.resolve,
    this.changes,
  });
  @override
  State<ChartInfoRegion> createState() => _ChartInfoRegionState();
}

class _ChartInfoRegionState extends State<ChartInfoRegion> {
  ChartInfo? _info;
  Offset? _position;
  Size _viewport = Size.zero;
  Offset? _scrollPointerPosition;
  int? _scrollPointer;
  ValueNotifier<bool>? _scrollActivity;
  bool _nestedHorizontalActive = false;
  bool _refreshScheduled = false;
  @override
  void initState() {
    super.initState();
    widget.changes?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ChartInfoRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_onScroll);
      widget.changes?.addListener(_onScroll);
    }
    _info = null;
    _position = null;
    _scrollPointerPosition = null;
    _scrollPointer = null;
    _detachScrollActivity();
  }

  void _onScroll() {
    if (_scrollPointerPosition != null) _position = _scrollPointerPosition;
    if (_position == null || _refreshScheduled) return;
    _refreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScheduled = false;
      if (mounted) {
        if (_scrollPointerPosition != null) _position = _scrollPointerPosition;
        _refresh();
      }
    });
  }

  void _onHorizontalActivity() {
    if (_scrollActivity?.value != true || _scrollPointerPosition == null)
      return;
    _nestedHorizontalActive = true;
    _show(_scrollPointerPosition!);
  }

  void _detachScrollActivity() {
    _scrollActivity?.removeListener(_onHorizontalActivity);
    _scrollActivity = null;
    _nestedHorizontalActive = false;
  }

  void _refresh() {
    final position = _position;
    final next =
        position == null || !(Offset.zero & _viewport).contains(position)
        ? null
        : widget.resolve(position, _viewport);
    if (_info?.title == next?.title &&
        _info?.detail == next?.detail &&
        _info?.color == next?.color)
      return;
    setState(() => _info = next);
  }

  void _show(Offset position) {
    _position = position;
    _refresh();
  }

  void _clear() {
    _position = null;
    _refresh();
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_onScroll);
    _detachScrollActivity();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _viewport = constraints.biggest;
      final colors = Theme.of(context).colorScheme;
      final region = ChartPointerRegion(
        cursor: MouseCursor.defer,
        onSelect: _show,
        onClear: () {
          if (!_nestedHorizontalActive) _clear();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: widget.child),
            if (_info != null)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 280,
                        maxHeight: math.max(0, _viewport.height - 16),
                      ),
                      child: Material(
                        key: const ValueKey('chart-info-card'),
                        color: colors.surfaceContainerHigh,
                        surfaceTintColor: Colors.transparent,
                        elevation: 6,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: colors.outline.withValues(alpha: 0.65),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _info!.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _info!.detail,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      if (widget.changes == null) return region;
      // An inner horizontal ScrollView owns its drag recognizer. Observe its
      // actual scrolling for tooltip updates instead of competing with it.
      return Listener(
        onPointerDown: (event) {
          _detachScrollActivity();
          _scrollPointer = event.pointer;
          _scrollPointerPosition = event.localPosition;
          final changes = widget.changes;
          if (changes is ScrollController && changes.hasClients) {
            _scrollActivity = changes.position.isScrollingNotifier;
            _scrollActivity!.addListener(_onHorizontalActivity);
          }
        },
        onPointerMove: (event) {
          if (_scrollPointer == event.pointer) {
            _scrollPointerPosition = event.localPosition;
            if (_nestedHorizontalActive) _show(event.localPosition);
          }
        },
        onPointerUp: (event) {
          if (_scrollPointer != event.pointer) return;
          _scrollPointerPosition = null;
          _scrollPointer = null;
          _detachScrollActivity();
          _clear();
        },
        onPointerCancel: (_) {
          _scrollPointerPosition = null;
          _scrollPointer = null;
          _detachScrollActivity();
          _clear();
        },
        child: region,
      );
    },
  );
}
