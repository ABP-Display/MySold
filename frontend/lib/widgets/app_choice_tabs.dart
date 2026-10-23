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
      Widget button(int index) => OutlinedButton.icon(
        key: ValueKey('operation-type-$index'),
        onPressed: () => onSelected(index),
        icon: Icon(icons[index], size: 18),
        label: Text(labels[index], textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 46),
          backgroundColor: selectedIndex == index
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : null,
          foregroundColor: selectedIndex == index
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          side: BorderSide(
            color: selectedIndex == index
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
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
