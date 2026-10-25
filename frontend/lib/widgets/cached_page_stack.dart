import 'package:flutter/material.dart';
import 'lazy_page_stack.dart';

/// Reuse visited page widgets while their input revision stays unchanged.
/// Refresh a stale page before it becomes visible, without rebuilding hidden
/// pages or discarding their scroll, form and expansion state.
class CachedPageStack extends StatefulWidget {
  final int index, itemCount;
  final Object revision;
  final IndexedWidgetBuilder itemBuilder;
  const CachedPageStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.revision,
    required this.itemBuilder,
  }) : assert(index >= 0 && index < itemCount);

  @override
  State<CachedPageStack> createState() => _CachedPageStackState();
}

class _CachedPageStackState extends State<CachedPageStack> {
  final _pages = <int, ({Object revision, Widget child})>{};

  @override
  Widget build(BuildContext context) {
    _pages.removeWhere((index, _) => index >= widget.itemCount);
    if (_pages[widget.index]?.revision != widget.revision) {
      _pages[widget.index] = (
        revision: widget.revision,
        child: widget.itemBuilder(context, widget.index),
      );
    }
    return LazyPageStack(
      index: widget.index,
      children: [
        for (var index = 0; index < widget.itemCount; index++)
          _pages[index]?.child ?? const SizedBox.shrink(),
      ],
    );
  }
}
