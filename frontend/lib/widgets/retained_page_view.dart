import 'package:flutter/material.dart';

/// Keep visited destinations and button-driven transitions, without swipe
/// navigation competing with the gestures inside each page.
class RetainedPageView extends StatelessWidget {
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final List<Widget> children;
  const RetainedPageView({
    super.key,
    required this.controller,
    required this.onPageChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => PageView(
    controller: controller,
    physics: const NeverScrollableScrollPhysics(),
    onPageChanged: onPageChanged,
    children: [
      for (var i = 0; i < children.length; i++)
        _RetainedDestination(
          key: ValueKey(i),
          child: AnimatedBuilder(
            animation: controller,
            child: children[i],
            builder: (context, child) {
              final page =
                  controller.hasClients &&
                      controller.position.hasContentDimensions
                  ? controller.page ?? controller.initialPage.toDouble()
                  : controller.initialPage.toDouble();
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
