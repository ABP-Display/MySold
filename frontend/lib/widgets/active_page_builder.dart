import 'package:flutter/material.dart';

/// Keep a hidden page's existing tree without starting its data/aggregation
/// work on provider notifications. Apply the latest inputs as it becomes visible.
class ActivePageBuilder extends StatefulWidget {
  final WidgetBuilder builder;
  const ActivePageBuilder({super.key, required this.builder});

  @override
  State<ActivePageBuilder> createState() => _ActivePageBuilderState();
}

class _ActivePageBuilderState extends State<ActivePageBuilder> {
  Widget? _content;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: TickerMode.getNotifier(context),
    builder: (context, active, _) {
      if (active) _content = widget.builder(context);
      return _content ?? const SizedBox.shrink();
    },
  );
}
