import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    return _VisiblePageStack(
      index: widget.index,
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

/// All destinations fill the same viewport. Unlike IndexedStack, laying out
/// this viewport must not also lay out every retained, invisible destination.
class _VisiblePageStack extends MultiChildRenderObjectWidget {
  final int index;
  const _VisiblePageStack({required this.index, required super.children});

  @override
  RenderIndexedStack createRenderObject(BuildContext context) =>
      _RenderVisiblePageStack(index: index);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderIndexedStack renderObject,
  ) {
    renderObject.index = index;
  }

  @override
  MultiChildRenderObjectElement createElement() => _VisiblePageElement(this);
}

class _VisiblePageElement extends MultiChildRenderObjectElement {
  _VisiblePageElement(_VisiblePageStack super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    visitor(children.elementAt((widget as _VisiblePageStack).index));
  }
}

class _RenderVisiblePageStack extends RenderIndexedStack {
  _RenderVisiblePageStack({required super.index})
    : super(fit: StackFit.expand, alignment: Alignment.topLeft);

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void performLayout() {
    assert(constraints.hasBoundedWidth && constraints.hasBoundedHeight);
    size = constraints.biggest;
    var child = firstChild;
    for (var i = 0; i < index!; i++) {
      child = childAfter(child!);
    }
    if (child != null) {
      child.layout(BoxConstraints.tight(size));
      (child.parentData! as StackParentData).offset = Offset.zero;
    }
  }
}
