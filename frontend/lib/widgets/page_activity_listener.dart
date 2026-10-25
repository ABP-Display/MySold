import 'package:flutter/material.dart';

/// Observe retained-page activation here, so the expensive page itself doesn't
/// become a TickerMode dependent and rebuild on every navigation change.
class PageActivityListener extends StatefulWidget {
  final VoidCallback onResume;
  final Widget child;
  const PageActivityListener({
    super.key,
    required this.onResume,
    required this.child,
  });

  @override
  State<PageActivityListener> createState() => _PageActivityListenerState();
}

class _PageActivityListenerState extends State<PageActivityListener> {
  bool _active = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.of(context);
    if (active && !_active) widget.onResume();
    _active = active;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
