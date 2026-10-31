import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/category_filter.dart';
import 'app_select_field.dart';

class CategoryFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final CategoryOrder order;
  final bool amountFiltered;
  final ValueChanged<String> onSearch;
  final ValueChanged<CategoryOrder> onOrder;
  final VoidCallback onAmount, onClearAmount;
  const CategoryFilterBar({
    super.key,
    required this.controller,
    required this.order,
    required this.amountFiltered,
    required this.onSearch,
    required this.onOrder,
    required this.onAmount,
    required this.onClearAmount,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final search = TextField(
        key: const ValueKey('category-name-filter'),
        controller: controller,
        onChanged: onSearch,
        decoration: InputDecoration(
          labelText: context.tr('Rechercher une catégorie'),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.tr('Effacer'),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onSearch('');
                  },
                ),
        ),
      );
      final sort = Row(
        children: [
          Expanded(
            child: AppSelectField<CategoryOrder>(
              key: const ValueKey('category-order'),
              label: context.tr('Trier par'),
              icon: Icons.sort,
              value: order,
              options: [
                for (final entry in const {
                  CategoryOrder.nameAscending: 'Nom : A → Z',
                  CategoryOrder.nameDescending: 'Nom : Z → A',
                  CategoryOrder.amountAscending: 'Montant croissant',
                  CategoryOrder.amountDescending: 'Montant décroissant',
                }.entries)
                  AppSelectOption(
                    value: entry.key,
                    label: context.tr(entry.value),
                  ),
              ],
              onChanged: (value) {
                if (value != null) onOrder(value);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            key: const ValueKey('category-amount-filter'),
            onPressed: onAmount,
            tooltip: context.tr('Filtrer par montant'),
            icon: Icon(
              amountFiltered ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            style: IconButton.styleFrom(
              foregroundColor: amountFiltered
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (constraints.maxWidth >= 720 &&
              MediaQuery.textScalerOf(context).scale(14) < 22)
            Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 12),
                Expanded(child: sort),
              ],
            )
          else ...[
            search,
            const SizedBox(height: 12),
            sort,
          ],
          if (amountFiltered)
            Align(
              alignment: Alignment.centerLeft,
              child: InputChip(
                label: Text(context.tr('Montant filtré')),
                onDeleted: onClearAmount,
              ),
            ),
        ],
      );
    },
  );
}
