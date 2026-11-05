import 'package:mysold/widgets/app_selection_button.dart';
import 'package:flutter/material.dart';

class AppChoiceTabs extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool floating;
  const AppChoiceTabs({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
    this.floating = false,
  });
  static double floatingHeight(BuildContext context) =>
      50 + MediaQuery.textScalerOf(context).scale(12) * 1.2;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (floating) {
        return SizedBox(
          height: floatingHeight(context),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < labels.length; index++)
                Expanded(
                  child: Tooltip(
                    message: labels[index],
                    child: AppSelectionButton(
                      key: ValueKey('operation-type-$index'),
                      selected: selectedIndex == index,
                      outlined: false,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.9),
                      isTab: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 8,
                      ),
                      onPressed: () => onSelected(index),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[index], size: 22),
                          const SizedBox(height: 6),
                          Text(
                            labels[index].characters.length > 10
                                ? '${labels[index].characters.take(6)}.'
                                : labels[index],
                            semanticsLabel: labels[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
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
