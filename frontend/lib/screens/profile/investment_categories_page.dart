import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/widgets/app_design.dart';

class InvestmentCategoriesPage extends StatefulWidget {
  final List<InvestmentTypeOption> options;
  final Set<String> usedTypes;
  final Future<void> Function(List<InvestmentTypeOption>) onSave;
  final String Function() createId;
  const InvestmentCategoriesPage({
    super.key,
    required this.options,
    required this.usedTypes,
    required this.onSave,
    required this.createId,
  });
  @override
  State<InvestmentCategoriesPage> createState() =>
      _InvestmentCategoriesPageState();
}

class _InvestmentCategoriesPageState extends State<InvestmentCategoriesPage> {
  late List<InvestmentTypeOption> _options;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _options = List.of(widget.options);
  }

  Future<void> _save(List<InvestmentTypeOption> next) async {
    setState(() => _saving = true);
    try {
      await widget.onSave(next);
      if (mounted) setState(() => _options = List.of(next));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('Erreur')} : $error')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _edit([InvestmentTypeOption? option]) async {
    final result = await showAppSheet<InvestmentTypeOption>(
      context: context,
      builder: (_) => _CategoryForm(
        initialName: option == null
            ? ''
            : investmentCategoryLabel(context, option),
        option: option,
        options: _options,
        id: option?.value ?? widget.createId(),
      ),
    );
    if (result == null || !mounted) return;
    await _save(
      option == null
          ? [..._options, result]
          : [for (final o in _options) o.value == result.value ? result : o],
    );
  }

  Future<void> _delete(InvestmentTypeOption option) async {
    if (option.value == 'other' || widget.usedTypes.contains(option.value))
      return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('Supprimer la catégorie ?')),
        content: Text(investmentCategoryLabel(context, option)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(context.tr('Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(context.tr('Supprimer')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await _save(_options.where((o) => o.value != option.value).toList());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appPageBar(
      context,
      title: Text(context.tr('Catégories d’investissement')),
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _saving || _options.length >= 40 ? null : () => _edit(),
      icon: const Icon(Icons.add),
      label: Text(context.tr('Catégorie')),
    ),
    body: Column(
      children: [
        SizedBox(
          height: 4,
          child: _saving ? const LinearProgressIndicator() : null,
        ),
        Expanded(
          child: ListView.separated(
            dragStartBehavior: DragStartBehavior.down,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            itemCount: _options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final option = _options[i];
              final protected =
                  option.value == 'other' ||
                  widget.usedTypes.contains(option.value);
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  key: ValueKey('investment-category-${option.value}'),
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: Icon(option.icon, color: option.color),
                  title: Text(
                    investmentCategoryLabel(context, option),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: _saving ? null : () => _edit(option),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.tr('Modifier'),
                        onPressed: _saving ? null : () => _edit(option),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: context.tr(
                          option.value == 'other'
                              ? 'Catégorie de secours'
                              : protected
                              ? 'Cette catégorie contient des actifs.'
                              : 'Supprimer',
                        ),
                        onPressed: _saving || protected
                            ? null
                            : () => _delete(option),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _CategoryForm extends StatefulWidget {
  final InvestmentTypeOption? option;
  final List<InvestmentTypeOption> options;
  final String id;
  final String initialName;
  const _CategoryForm({
    required this.option,
    required this.options,
    required this.id,
    required this.initialName,
  });
  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late Color _color;
  late IconData _icon;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _color = widget.option?.color ?? const Color(0xff77b8ae);
    _icon = widget.option?.icon ?? Icons.category_outlined;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _chooseColor() async {
    var color = _color;
    final result = await showDialog<Color>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(context.tr('Choisir une couleur')),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: color,
            enableAlpha: false,
            hexInputBar: true,
            onColorChanged: (value) => color = value,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(context.tr('Annuler')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, color),
            child: Text(context.tr('Valider')),
          ),
        ],
      ),
    );
    if (result != null && mounted) setState(() => _color = result);
  }

  Future<void> _chooseIcon() async {
    final result = await showIconPicker(
      context,
      configuration: SinglePickerConfiguration(
        adaptiveDialog: true,
        showSearchBar: true,
        showTooltips: true,
        iconPackModes: const [IconPack.allMaterial],
        title: Text(context.tr('Choisir une icone')),
        closeChild: Text(context.tr('Fermer')),
        searchHintText: context.tr('Rechercher une icone'),
        noResultsText: context.tr('Aucun resultat pour :'),
      ),
    );
    if (result != null && mounted) setState(() => _icon = result.data);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(
              widget.option == null
                  ? 'Nouvelle catégorie d’investissement'
                  : 'Modifier la catégorie d’investissement',
            ),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            maxLength: 60,
            decoration: InputDecoration(labelText: context.tr('Nom')),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty ||
                  widget.options.any(
                    (o) =>
                        o.value != widget.id &&
                        o.label.toLowerCase() == name.toLowerCase(),
                  )) {
                return context.tr('Un nom unique est requis.');
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.outlined(
                tooltip: context.tr('Choisir une couleur'),
                onPressed: _chooseColor,
                icon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.outlined(
                tooltip: context.tr('Choisir une icone'),
                onPressed: _chooseIcon,
                icon: Icon(_icon, color: _color),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              if (_form.currentState!.validate())
                Navigator.pop(
                  context,
                  InvestmentTypeOption(
                    value: widget.id,
                    label:
                        widget.option != null &&
                            _name.text.trim() == widget.initialName
                        ? widget.option!.label
                        : _name.text.trim(),
                    color: _color,
                    icon: _icon,
                  ),
                );
            },
            icon: const Icon(Icons.check),
            label: Text(context.tr('Enregistrer')),
          ),
        ],
      ),
    ),
  );
}
