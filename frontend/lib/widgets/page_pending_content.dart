import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

/// A first, uncached read keeps the page heading and its date controls usable.
/// The branded full-screen cover is reserved for starting/unlocking the app.
class PagePendingContent extends StatelessWidget {
  final Widget header;
  const PagePendingContent({super.key, required this.header});
  @override
  Widget build(BuildContext context) => ListView(
    dragStartBehavior: DragStartBehavior.down,
    padding: const EdgeInsets.all(20),
    children: [
      header,
      const SizedBox(height: 20),
      const RepaintBoundary(child: LinearProgressIndicator(minHeight: 2)),
    ],
  );
}
