import 'package:flutter/material.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_selection_button.dart';

/// Floating route navigation: only the menu surface intercepts gestures.
class AppPageTabMenu extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final String keyPrefix;
  final bool scrollable;

  const AppPageTabMenu({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    required this.keyPrefix,
    this.scrollable = false,
  });

  static const _style = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
  );

  static double itemWidth(BuildContext context) =>
      104 * MediaQuery.textScalerOf(context).scale(13) / 13;

  static double heightOf(
    BuildContext context,
    List<String> labels, {
    bool scrollable = false,
  }) {
    final width =
        (MediaQuery.sizeOf(context).width - 16).clamp(0.0, 1040.0) - 12;
    final item = scrollable ? itemWidth(context) : width / labels.length;
    var textHeight = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelLarge!.merge(_style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (item - 20).clamp(1.0, double.infinity));
      if (painter.height > textHeight) textHeight = painter.height;
      painter.dispose();
    }
    return 64 + textHeight;
  }

  static double clearance(
    BuildContext context,
    List<String> labels, {
    bool scrollable = false,
  }) =>
      heightOf(context, labels, scrollable: scrollable) +
      24 +
      MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.viewInsetsOf(context).bottom > 0)
      return const SizedBox.shrink();
    final height = heightOf(context, labels, scrollable: scrollable);
    Widget button(int index) => AppSelectionButton(
      key: ValueKey('$keyPrefix-tab-$index'),
      selected: selectedIndex == index,
      outlined: false,
      isTab: true,
      selectionInset: const EdgeInsets.all(3),
      borderRadius: BorderRadius.circular(15),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
      onPressed: () => onSelected(index),
      child: Tooltip(
        message: labels[index],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icons[index], size: 22),
            const SizedBox(height: 6),
            Text(
              labels[index],
              textAlign: TextAlign.center,
              style: _style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: AppMenuSurface(
            floating: true,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: SizedBox(
                height: height - 12,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (scrollable &&
                        constraints.maxWidth <
                            labels.length * itemWidth(context)) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < labels.length; i++)
                              SizedBox(
                                width: itemWidth(context),
                                child: button(i),
                              ),
                          ],
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Expanded(child: button(i)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
