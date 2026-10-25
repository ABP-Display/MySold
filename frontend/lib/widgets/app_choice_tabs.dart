import 'package:mysold/widgets/app_selection_button.dart';
import 'package:flutter/material.dart';

class AppChoiceTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const AppChoiceTabs({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      Widget button(int index) => AppSelectionButton(
        key: ValueKey('operation-type-$index'),
        selected: selectedIndex == index,
        onPressed: () => onSelected(index),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icons[index], size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(labels[index], textAlign: TextAlign.center)),
          ],
        ),
      );
      if (constraints.maxWidth >= 760)
        return Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(child: button(index)),
            ],
          ],
        );
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0) const SizedBox(width: 8),
              button(index),
            ],
          ],
        ),
      );
    },
  );
}
