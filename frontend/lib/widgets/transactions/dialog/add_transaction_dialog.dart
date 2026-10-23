import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/local_auth.dart';

import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';

/// --- DIALOG PRINCIPAL POUR CHOISIR LE TYPE ---
Future<void> showAddOperationDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(context.tr('Ajouter une operation')),
      children: [
        SimpleDialogOption(
          child: Text(context.tr('Transaction')),
          onPressed: () {
            Navigator.pop(ctx);
            showDialog(
              context: context,
              builder: (_) => const AddTransactionDialog(),
            );
          },
        ),
      ],
    ),
  );
}

/// --- TRANSACTION CLASSIQUE ---
class AddTransactionDialog extends StatefulWidget {
  final TransactionModel? existingTransaction;

  const AddTransactionDialog({super.key, this.existingTransaction});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _type = 'expense';
  String? _compteId;
  String? _categorieId;

  Map<String, String> _comptes = {};
  Map<String, Map<String, dynamic>> _categories = {};
  bool _isSaving = false;

  double _parseMoney(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    return double.parse(parsed.toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingTransaction != null) {
      final t = widget.existingTransaction!;
      _amountCtrl.text = t.amount.toStringAsFixed(2);
      _descCtrl.text = t.description;
      _selectedDate = t.date;
      _compteId = t.fromAccountId;
      _categorieId = t.categoryId;
      _type = t.type;
    }
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final userId = LocalAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final references = context.read<UserDataProvider>();
    final comptes = await references.getManualAccounts();
    final categories = await references.getCategories(type: _type);

    if (!mounted) return;
    setState(() {
      _comptes = comptes;
      _categories = categories;
      _compteId ??= comptes.keys.firstOrNull;
      _categorieId = categories.containsKey(_categorieId)
          ? _categorieId
          : categories.keys.firstOrNull;
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_compteId == null || _categorieId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Selectionnez un compte et une categorie valides.'),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final montant = _parseMoney(_amountCtrl.text);
    if (montant <= 0) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Le montant doit etre superieur a 0.')),
        ),
      );
      return;
    }

    final userId = LocalAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isSaving = false);
      return;
    }

    final service = BudgetService(userId: userId);

    try {
      // 🔹 Création de l'objet TransactionModel
      final t = TransactionModel(
        id: widget.existingTransaction?.id,
        amount: montant,
        date: _selectedDate,
        description: _descCtrl.text.trim().toUpperCase(),
        type: _type,
        fromAccountId: _compteId,
        categoryId: (_type == 'income' || _type == 'expense')
            ? _categorieId
            : null,
        toAccountId: null,
        investmentId: null,
      );

      if (widget.existingTransaction == null) {
        await service.addTransaction(t);
      } else {
        await service.updateTransaction(widget.existingTransaction!, t);
      }
      if (mounted) {
        context.read<UserDataProvider>().markFinancialDataChanged();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _errorMessage(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final isEditing = widget.existingTransaction != null;

    // Si aucune catégorie encore sélectionnée → on cherche "Others"
    if (_categorieId == null && _categories.isNotEmpty) {
      final defaultEntry = _categories.entries.firstWhere(
        (e) => (e.value['name'] ?? '').toLowerCase() == "others",
        orElse: () => _categories.entries.first,
      );
      _categorieId = defaultEntry.key;
    }

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppDialogHeader(
                  icon: Icons.receipt_long_outlined,
                  title: isEditing
                      ? context.tr('Modifier la transaction')
                      : context.tr('Nouvelle transaction'),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final type in ['expense', 'income'])
                              ChoiceChip(
                                label: Text(
                                  context.tr(
                                    type == 'expense' ? 'Depense' : 'Revenu',
                                  ),
                                ),
                                selected: _type == type,
                                onSelected: (_) {
                                  if (_type == type) return;
                                  setState(() {
                                    _type = type;
                                    _categorieId = null;
                                  });
                                  _loadDropdownData();
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '${context.tr('Montant')} ($currency)',
                            prefixIcon: const Icon(Icons.euro),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return context.tr('Entrer un montant');
                            }
                            final parsed = double.tryParse(
                              v.replaceAll(',', '.'),
                            );
                            if (parsed == null) {
                              return context.tr('Montant invalide');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText: context.tr('Description'),
                            prefixIcon: const Icon(Icons.description),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.date_range),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _pickDate,
                              child: Text(context.tr('Changer la date')),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        AppSelectField<String>(
                          value: _compteId,
                          options: _comptes.entries
                              .map(
                                (e) => AppSelectOption(
                                  value: e.key,
                                  label: e.value,
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _compteId = v),
                          label: context.tr('Compte'),
                          icon: Icons.account_balance_wallet,
                        ),
                        const SizedBox(height: 12),
                        AppSelectField<String>(
                          value: _categorieId,
                          options: _categories.entries
                              .map(
                                (e) => AppSelectOption(
                                  value: e.key,
                                  label: (e.value['name'] ?? '').toString(),
                                  color: e.value['color'] is int
                                      ? Color(e.value['color'])
                                      : null,
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _categorieId = v),
                          label: context.tr('Categorie'),
                          icon: Icons.category,
                        ),
                        const SizedBox(height: 20),
                        if (_isSaving)
                          const CircularProgressIndicator()
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _save,
                                  icon: const Icon(Icons.save),
                                  label: Text(
                                    isEditing
                                        ? context.tr('Modifier')
                                        : context.tr('Enregistrer'),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: const Size.fromHeight(48),
                                  ),
                                  child: Text(context.tr('Annuler')),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
