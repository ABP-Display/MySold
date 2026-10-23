import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';

class AddCategoryPage extends StatefulWidget {
  final String userId;
  final String? categoryId;
  final Map<String, dynamic>? existingData;

  const AddCategoryPage({
    super.key,
    required this.userId,
    this.categoryId,
    this.existingData,
  });

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String _type = 'expense';
  Color _color = Colors.blue;
  IconData _icon = Icons.category;
  bool _isSaving = false;

  bool get _isEditing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();

    final data = widget.existingData;
    if (data != null) {
      _nameCtrl.text = data['name'] ?? '';
      _type = data['type'] ?? 'expense';
      _color = Color(data['color'] ?? Colors.blue.value);
      _icon = IconData(
        data['icon'] ?? Icons.category.codePoint,
        fontFamily: 'MaterialIcons',
      );
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim().toUpperCase(),
      'type': _type,
      'color': _color.value,
      'icon': _icon.codePoint,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('categories');

    try {
      if (_isEditing) {
        await ref.doc(widget.categoryId).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.add(data);
      }

      if (!mounted) return;
      context.read<UserDataProvider>().invalidateReferences();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Categorie enregistree'))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${context.tr('Erreur')} : $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickColor() async {
    final color = await showDialog<Color>(
      context: context,
      builder: (context) {
        final presetColors = [
          Colors.redAccent,
          Colors.green,
          Colors.blue,
          Colors.orange,
          Colors.purple,
          Colors.pink,
          Colors.teal,
          Colors.brown,
          Colors.amber,
        ];

        return AlertDialog(
          title: Text(context.tr('Choisir une couleur')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: presetColors.map((color) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => Navigator.pop(context, color),
                    child: Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withOpacity(0.20),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCustomColorPicker(context),
                  icon: const Icon(Icons.palette_outlined),
                  label: Text(context.tr('Couleur personnalisee')),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (color != null) {
      setState(() => _color = color);
    }
  }

  Future<void> _openCustomColorPicker(BuildContext parentContext) async {
    Color tempColor = _color;

    final color = await showDialog<Color>(
      context: parentContext,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Couleur personnalisee')),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (value) => tempColor = value,
              enableAlpha: false,
              labelTypes: const [ColorLabelType.rgb],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Annuler')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempColor),
              child: Text(context.tr('Valider')),
            ),
          ],
        );
      },
    );

    if (color != null && mounted) {
      Navigator.pop(parentContext, color);
    }
  }

  Future<void> _pickIcon() async {
    final IconPickerIcon? icon = await showIconPicker(
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

    if (icon != null) {
      setState(() => _icon = icon.data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.tr('Modifier la categorie')
              : context.tr('Nouvelle categorie'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildForm(),
            const SizedBox(height: 18),
            _buildPersonalization(),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveCategory,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _isEditing
                      ? context.tr('Mettre a jour')
                      : context.tr('Ajouter'),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon, color: _color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? context.tr('Ajuster la categorie')
                      : context.tr('Creer une categorie'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _type == 'expense'
                      ? context.tr('Elle apparaitra dans les depenses.')
                      : context.tr('Elle apparaitra dans les revenus.'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.64),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: context.tr('Nom de la categorie'),
                hintText: context.tr('Ex: COURSES'),
                prefixIcon: const Icon(Icons.category_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Entrez un nom de categorie');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _buildTypeSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _TypeChoice(
            label: context.tr('Depense'),
            icon: Icons.trending_down_outlined,
            isSelected: _type == 'expense',
            onTap: () => setState(() => _type = 'expense'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TypeChoice(
            label: context.tr('Revenu'),
            icon: Icons.trending_up_outlined,
            isSelected: _type == 'income',
            onTap: () => setState(() => _type = 'income'),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalization() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Personnalisation'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickColor,
                  icon: Icon(Icons.color_lens_outlined, color: _color),
                  label: Text(context.tr('Couleur')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickIcon,
                  icon: Icon(_icon),
                  label: Text(context.tr('Icone')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}

class _TypeChoice extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChoice({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isSelected
        ? colorScheme.primary
        : colorScheme.onSurface.withOpacity(0.66);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withOpacity(0.35)
                : colorScheme.outline.withOpacity(0.16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
