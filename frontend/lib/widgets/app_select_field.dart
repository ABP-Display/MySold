import 'package:flutter/material.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/widgets/app_design.dart';

class AppSelectOption<T> {
  final T value;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  const AppSelectOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.icon,
    this.color,
  });
}

class _Selection<T> {
  final T value;
  const _Selection(this.value);
}

/// A themed form selector with a searchable list and a responsive sheet/dialog.
class AppSelectField<T> extends FormField<T> {
  final List<AppSelectOption<T>> options;
  final String label;
  final String? hint;
  final IconData icon;
  final ValueChanged<T?>? onChanged;
  AppSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.icon,
    T? value,
    this.hint,
    this.onChanged,
    super.validator,
  }) : super(
         initialValue: value,
         enabled: onChanged != null,
         builder: (state) => (state as _AppSelectFieldState<T>)._build(),
       );
  @override
  FormFieldState<T> createState() => _AppSelectFieldState<T>();
}

class _AppSelectFieldState<T> extends FormFieldState<T> {
  AppSelectField<T> get field => widget as AppSelectField<T>;
  @override
  void didUpdateWidget(covariant AppSelectField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue)
      setValue(widget.initialValue);
  }

  Future<void> _open() async {
    final selection = await showAppSheet<_Selection<T>>(
      context: context,
      builder: (context) => _SelectList<T>(
        label: field.label,
        options: field.options,
        selected: value,
        defaultIcon: field.icon,
      ),
    );
    if (!mounted || selection == null) return;
    didChange(selection.value);
    field.onChanged?.call(selection.value);
  }

  Widget _build() {
    final selected = field.options
        .where((option) => option.value == value)
        .firstOrNull;
    return Semantics(
      button: true,
      label: field.label,
      child: InkWell(
        onTap: field.onChanged == null ? null : _open,
        borderRadius: BorderRadius.circular(10),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(
            labelText: field.label,
            errorText: errorText,
            enabled: field.onChanged != null,
            prefixIcon: Icon(
              selected?.icon ?? field.icon,
              color: selected?.color,
            ),
            suffixIcon: const Icon(Icons.unfold_more_rounded, size: 20),
          ),
          child: Text(
            selected?.label ?? field.hint ?? context.tr('Sélectionner'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: selected == null
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectList<T> extends StatefulWidget {
  final String label;
  final List<AppSelectOption<T>> options;
  final T? selected;
  final IconData defaultIcon;
  const _SelectList({
    required this.label,
    required this.options,
    required this.selected,
    required this.defaultIcon,
  });
  @override
  State<_SelectList<T>> createState() => _SelectListState<T>();
}

class _SelectListState<T> extends State<_SelectList<T>> {
  String _query = '';
  String _normalize(String value) {
    var result = value.toLowerCase().trim();
    const accents = {
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accents.forEach((from, to) => result = result.replaceAll(from, to));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final matches = widget.options
        .where(
          (option) => _normalize(
            '${option.label} ${option.subtitle ?? ''}',
          ).contains(_normalize(_query)),
        )
        .toList();
    final height =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.viewInsetsOf(context).bottom) *
        0.42;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            onChanged: (query) => setState(() => _query = query),
            decoration: InputDecoration(
              hintText: context.tr('Rechercher'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: height.clamp(100.0, 360.0),
            child: matches.isEmpty
                ? Center(
                    child: Text(
                      context.tr('Aucun résultat'),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.separated(
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final option = matches[index];
                      final selected = option.value == widget.selected;
                      final accent = option.color ?? colors.primary;
                      return Material(
                        color: selected
                            ? colors.primary.withValues(alpha: 0.1)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: selected
                                ? colors.primary.withValues(alpha: 0.45)
                                : colors.outlineVariant,
                          ),
                        ),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              option.icon ?? widget.defaultIcon,
                              color: accent,
                              size: 19,
                            ),
                          ),
                          title: Text(
                            option.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: option.subtitle == null
                              ? null
                              : Text(
                                  option.subtitle!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                          trailing: Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: selected ? colors.primary : colors.outline,
                          ),
                          onTap: () =>
                              Navigator.pop(context, _Selection(option.value)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
