import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';

typedef CategoryAmountRange = ({double? minimum, double? maximum});

class CategoryAmountFilter extends StatefulWidget {
  final double? minimum, maximum;
  const CategoryAmountFilter({super.key, this.minimum, this.maximum});
  @override
  State<CategoryAmountFilter> createState() => _CategoryAmountFilterState();
}

class _CategoryAmountFilterState extends State<CategoryAmountFilter> {
  final _form = GlobalKey<FormState>();
  late final _minimum = TextEditingController(
    text: widget.minimum?.toString() ?? '',
  );
  late final _maximum = TextEditingController(
    text: widget.maximum?.toString() ?? '',
  );
  double? _parse(String value) => double.tryParse(
    value.trim().replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.'),
  );

  String? _validate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = _parse(text);
    return value == null || !value.isFinite || value < 0
        ? context.tr('Saisissez un montant positif ou nul.')
        : null;
  }

  @override
  void dispose() {
    _minimum.dispose();
    _maximum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      24 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr('Filtrer par montant'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Montant cumulé des transactions de chaque catégorie.'),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('category-minimum'),
            controller: _minimum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.tr('Montant min')),
            validator: _validate,
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('category-maximum'),
            controller: _maximum,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: context.tr('Montant max')),
            validator: (text) {
              final error = _validate(text);
              if (error != null) return error;
              final low = _parse(_minimum.text), high = _parse(text ?? '');
              return low != null && high != null && high < low
                  ? context.tr(
                      'Le maximum doit être supérieur ou égal au minimum.',
                    )
                  : null;
            },
          ),
          const SizedBox(height: 20),
          OverflowBar(
            spacing: 12,
            overflowSpacing: 12,
            children: [
              TextButton(
                onPressed: () => Navigator.pop<CategoryAmountRange>(context, (
                  minimum: null,
                  maximum: null,
                )),
                child: Text(context.tr('Réinitialiser')),
              ),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate())
                    Navigator.pop<CategoryAmountRange>(context, (
                      minimum: _parse(_minimum.text),
                      maximum: _parse(_maximum.text),
                    ));
                },
                child: Text(context.tr('Appliquer')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
