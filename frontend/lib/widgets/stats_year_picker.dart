import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'app_design.dart';

Future<int?> chooseStatsYear(BuildContext context, int year) =>
    showAppSheet<int>(
      context: context,
      builder: (_) => StatsYearPicker(year: year),
    );

class StatsYearPicker extends StatefulWidget {
  final int year;
  const StatsYearPicker({super.key, required this.year});
  @override
  State<StatsYearPicker> createState() => _StatsYearPickerState();
}

class _StatsYearPickerState extends State<StatsYearPicker> {
  final _form = GlobalKey<FormState>();
  late final _year = TextEditingController(text: '${widget.year}');
  @override
  void dispose() {
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
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
            context.tr('Choisir une année'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const ValueKey('stats-year-input'),
            controller: _year,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.tr('Année')),
            validator: (value) {
              final year = int.tryParse(value?.trim() ?? '');
              return year == null || year < 1 || year > 9998
                  ? context.tr('Saisissez une année entre 1 et 9998.')
                  : null;
            },
          ),
          const SizedBox(height: 20),
          OverflowBar(
            spacing: 12,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.tr('Annuler')),
              ),
              FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate())
                    Navigator.pop(context, int.parse(_year.text.trim()));
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
