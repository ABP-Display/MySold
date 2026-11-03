import 'package:flutter/material.dart';

/// Keep a bounded number of visited transaction rows, so reversing a scroll
/// does not repeatedly recreate their text layout, cards and gesture handlers.
class ScrollItemRetention extends StatefulWidget {
  final Widget child;
  final int capacity;
  const ScrollItemRetention({
    super.key,
    required this.child,
    this.capacity = 48,
  }) : assert(capacity > 0);

  @override
  State<ScrollItemRetention> createState() => _ScrollItemRetentionState();
}

class _ScrollItemRetentionState extends State<ScrollItemRetention> {
  final _items = <_RetainedScrollItemState>{};
  bool _scheduled = false;

  void _remember(_RetainedScrollItemState item) {
    _items.add(item);
    if (_items.length <= widget.capacity || _scheduled) return;
    _scheduled = true;
    // KeepAlive notifications must not invalidate the sliver during its layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      while (_items.length > widget.capacity) {
        final oldest = _items.first;
        _items.remove(oldest);
        oldest.release();
      }
    });
  }

  @override
  Widget build(BuildContext context) =>
      _RetentionScope(owner: this, child: widget.child);
}

class _RetentionScope extends InheritedWidget {
  final _ScrollItemRetentionState owner;
  const _RetentionScope({required this.owner, required super.child});
  @override
  bool updateShouldNotify(_RetentionScope oldWidget) =>
      owner != oldWidget.owner;
}

class RetainedScrollItem extends StatefulWidget {
  final Widget child;
  const RetainedScrollItem({super.key, required this.child});

  @override
  State<RetainedScrollItem> createState() => _RetainedScrollItemState();
}

class _RetainedScrollItemState extends State<RetainedScrollItem>
    with AutomaticKeepAliveClientMixin {
  _ScrollItemRetentionState? _owner;
  bool _retained = true;
  @override
  bool get wantKeepAlive => _retained;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = context
        .dependOnInheritedWidgetOfExactType<_RetentionScope>()!
        .owner;
    if (owner != _owner) {
      _owner?._items.remove(this);
      _owner = owner;
      owner._remember(this);
    }
  }

  void release() {
    if (!mounted) return;
    _retained = false;
    updateKeepAlive();
  }

  @override
  void dispose() {
    _owner?._items.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
