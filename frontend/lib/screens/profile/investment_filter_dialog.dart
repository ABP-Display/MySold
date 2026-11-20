import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';

class InvestmentFilterDialog extends StatefulWidget {
  final List<InvestmentTypeOption> options;
  final Set<String> selected;

  const InvestmentFilterDialog({
    super.key,
    required this.options,
    required this.selected,
  });

  @override
  State<InvestmentFilterDialog> createState() => _InvestmentFilterDialogState();
}

class _InvestmentFilterDialogState extends State<InvestmentFilterDialog> {
  late final Set<String> _selected = widget.selected.intersection(
    widget.options.map((o) => o.value).toSet(),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(context.tr('Filtres')),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      content: SizedBox(
        width: 380,
        child: ListView(
          shrinkWrap: true,
          dragStartBehavior: DragStartBehavior.down,
          children: [
            CheckboxListTile(
              key: const ValueKey('investment-filter-all'),
              value: _selected.isEmpty,
              title: Text(context.tr('Tout afficher')),
              secondary: const Icon(Icons.select_all),
              onChanged: (_) => setState(_selected.clear),
            ),
            const Divider(),
            for (final option in widget.options)
              CheckboxListTile(
                key: ValueKey('investment-filter-${option.value}'),
                value: _selected.contains(option.value),
                title: Text(
                  investmentCategoryLabel(context, option),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: Icon(option.icon, color: option.color),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(option.value);
                    if (_selected.length == widget.options.length) {
                      _selected.clear();
                    }
                  } else {
                    _selected.remove(option.value);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Annuler')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, Set<String>.of(_selected)),
          child: Text(context.tr('Appliquer')),
        ),
      ],
    );
  }
}
