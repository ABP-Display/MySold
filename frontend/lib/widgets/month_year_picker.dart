import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'app_design.dart';
import 'app_selection_button.dart';

Future<DateTime?> showMonthYearPicker(
  BuildContext context,
  DateTime initialDate,
) => showAppSheet<DateTime>(
  context: context,
  builder: (_) => MonthYearPicker(initialDate: initialDate),
);

class MonthYearPicker extends StatefulWidget {
  final DateTime initialDate;
  const MonthYearPicker({super.key, required this.initialDate});
  @override
  State<MonthYearPicker> createState() => _MonthYearPickerState();
}

class _MonthYearPickerState extends State<MonthYearPicker> {
  final _form = GlobalKey<FormState>();
  late int _month = widget.initialDate.month;
  late final _year = TextEditingController(
    text: widget.initialDate.year.toString(),
  );

  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  void _moveYear(int delta) {
    final year = int.tryParse(_year.text.trim());
    if (year == null || year + delta < 1 || year + delta > 9999) {
      _form.currentState!.validate();
      return;
    }
    _year.text = (year + delta).toString();
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Choisir un mois'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              IconButton(
                onPressed: () => _moveYear(-1),
                tooltip: context.tr('Année précédente'),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('month-picker-year'),
                  controller: _year,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(labelText: context.tr('Année')),
                  validator: (value) {
                    final year = int.tryParse(value?.trim() ?? '');
                    return year == null || year < 1 || year > 9999
                        ? context.tr('Saisissez une année entre 1 et 9999.')
                        : null;
                  },
                ),
              ),
              IconButton(
                onPressed: () => _moveYear(1),
                tooltip: context.tr('Année suivante'),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, bounds) {
              final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
              final columns = bounds.maxWidth < 340 || scale > 1.4 ? 2 : 3;
              final width = (bounds.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var month = 1; month <= 12; month++)
                    SizedBox(
                      width: width,
                      height: 52 * scale,
                      child: AppSelectionButton(
                        key: ValueKey('month-picker-$month'),
                        selected: month == _month,
                        onPressed: () => setState(() => _month = month),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Center(
                          child: Text(
                            DateFormat.MMMM(
                              Localizations.localeOf(context).toString(),
                            ).format(DateTime(2000, month)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, height: 1.25),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          OverflowBar(
            spacing: 12,
            overflowSpacing: 12,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Annuler')),
              ),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate())
                    Navigator.pop(
                      context,
                      DateTime(int.parse(_year.text.trim()), _month, 1),
                    );
                },
                child: Text(context.tr('Afficher')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
