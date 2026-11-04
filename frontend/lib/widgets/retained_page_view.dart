import 'dart:async';
import 'package:flutter/material.dart';

/// Keep visited destinations and button-driven transitions, without swipe
/// navigation competing with the gestures inside each page.
class RetainedPageView extends StatefulWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;

  /// Optional one-time readiness signals, completed on data success or error.
  /// Each destination gets a layout/paint pass before the workspace is exposed.
  final List<Future<void>>? readiness;
  final VoidCallback? onPrepared;
  const RetainedPageView({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.children,
    this.readiness,
    this.onPrepared,
  }) : assert(readiness == null || readiness.length == children.length);

  @override
  State<RetainedPageView> createState() => _RetainedPageViewState();
}

class _RetainedPageViewState extends State<RetainedPageView> {
  final _disposed = Completer<void>();
  late bool _preparing = widget.readiness != null;

  @override
  void initState() {
    super.initState();
    if (_preparing) {
      final readiness = widget.readiness!
          .map(
            (future) => future.then<void>(
              (_) {},
              onError: (Object _, StackTrace __) {},
            ),
          )
          .toList();
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare(readiness));
    }
  }

  Future<void> _prepare(List<Future<void>> readiness) async {
    final initial = widget.controller.initialPage;
    for (var i = 0; i < readiness.length; i++) {
      if (!mounted) return;
      widget.controller.jumpToPage(i);
      await _nextFrame();
      if (!mounted) return;
      // A failed destination must show its own error/retry state, not trap
      // the entire workspace behind the startup cover.
      await Future.any([readiness[i], _disposed.future]);
      if (!mounted) return;
      await _nextFrame();
    }
    if (!mounted) return;
    widget.controller.jumpToPage(initial);
    await _nextFrame();
    if (!mounted) return;
    setState(() => _preparing = false);
    widget.onPrepared?.call();
  }

  Future<void> _nextFrame() {
    // Also progress when reduced motion disables the startup spinner.
    WidgetsBinding.instance.scheduleFrame();
    return WidgetsBinding.instance.endOfFrame;
  }

  @override
  void dispose() {
    _disposed.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    controller: widget.controller,
    physics: const NeverScrollableScrollPhysics(),
    onPageChanged: (index) {
      if (!_preparing) widget.onPageChanged(index);
    },
    children: [
      for (var i = 0; i < widget.children.length; i++)
        _RetainedDestination(
          key: ValueKey(i),
          child: AnimatedBuilder(
            animation: widget.controller,
            child: widget.children[i],
            builder: (context, child) {
              final page =
                  widget.controller.hasClients &&
                      widget.controller.position.hasContentDimensions
                  ? widget.controller.page ??
                        widget.controller.initialPage.toDouble()
                  : widget.controller.initialPage.toDouble();
              return TickerMode(
                enabled: (page - i).abs() < 1,
                child: ExcludeFocus(
                  excluding: (page - i).abs() >= .5,
                  child: child!,
                ),
              );
            },
          ),
        ),
    ],
  );
}

class _RetainedDestination extends StatefulWidget {
  final Widget child;
  const _RetainedDestination({super.key, required this.child});
  @override
  State<_RetainedDestination> createState() => _RetainedDestinationState();
}

class _RetainedDestinationState extends State<_RetainedDestination>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(child: widget.child);
  }
}
