import 'package:flutter/material.dart';

/// Open destinations directly, mount them on demand and retain their state.
/// Hidden pages neither tick animations nor receive focus or pointer events.
class LazyPageStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const LazyPageStack({super.key, required this.index, required this.children})
    : assert(index >= 0 && index < children.length);

  @override
  State<LazyPageStack> createState() => _LazyPageStackState();
}

class _LazyPageStackState extends State<LazyPageStack> {
  final Set<int> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var index = 0; index < widget.children.length; index++)
          if (_visited.contains(index))
            TickerMode(
              enabled: index == widget.index,
              child: HeroMode(
                enabled: index == widget.index,
                child: ExcludeFocus(
                  excluding: index != widget.index,
                  child: PrimaryScrollController.none(
                    child: RepaintBoundary(child: widget.children[index]),
                  ),
                ),
              ),
            )
          else
            const SizedBox.shrink(),
      ],
    );
  }
}
