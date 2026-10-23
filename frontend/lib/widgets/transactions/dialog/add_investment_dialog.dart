import 'package:mysold/widgets/app_design.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/data/document_store.dart';

import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
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
          child: Text(context.tr('Investissement')),
          onPressed: () {
            Navigator.pop(ctx);
            showDialog(
              context: context,
              builder: (_) => const AddInvestmentDialog(),
            );
          },
        ),
      ],
    ),
  );
}

/// --- INVESTISSEMENT ---
class AddInvestmentDialog extends StatefulWidget {
  final TransactionModel? existingTransaction;
  const AddInvestmentDialog({super.key, this.existingTransaction});

  @override
  State<AddInvestmentDialog> createState() => _AddInvestmentDialogState();
}

class _AddInvestmentDialogState extends State<AddInvestmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _destinationInvestmentId;

  Map<String, String> _sourceAccounts = {};
  Map<String, String> _supportAccounts = {};
  Map<String, String> _investments = {};
  Map<String, String> _investmentHoldingAccounts = {};
  bool _isSaving = false;

  double _parseMoney(String value) {
    final parsed = double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
    return double.parse(parsed.toStringAsFixed(2));
  }

  @override
  void initState() {
    super.initState();
    final existing = widget.existingTransaction;
    if (existing != null) {
      _amountCtrl.text = existing.amount.toStringAsFixed(2);
      _selectedDate = existing.date;
      _sourceAccountId = existing.fromAccountId;
      _destinationAccountId = existing.toAccountId;
      _destinationInvestmentId = existing.investmentId;
    }
    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    final userId = LocalAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final accountsRef = DocumentStore.instance
        .collection('users')
        .doc(userId)
        .collection('accounts');
    final accountsSnapshot = await accountsRef.get();
    final comptes = {
      for (final doc in accountsSnapshot.docs)
        doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
    };
    final manualAccounts = {
      for (final doc in accountsSnapshot.docs)
        if (doc.data()['managedByInvestments'] != true)
          doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
    };
    final investmentsSnapshot = await DocumentStore.instance
        .collection('users')
        .doc(userId)
        .collection('investments')
        .get();
    final investissements = {
      for (final doc in investmentsSnapshot.docs)
        doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
    };
    final investmentHoldingAccounts = {
      for (final doc in investmentsSnapshot.docs)
        if ((doc.data()['holdingAccountId'] ?? '').toString().isNotEmpty)
          doc.id: doc.data()['holdingAccountId'].toString(),
    };
    final supportAccounts = {
      for (final accountId in investmentHoldingAccounts.values.toSet())
        if (comptes.containsKey(accountId)) accountId: comptes[accountId]!,
    };

    if (!mounted) return;
    setState(() {
      _sourceAccounts = manualAccounts;
      _supportAccounts = supportAccounts;
      _investments = investissements;
      _investmentHoldingAccounts = investmentHoldingAccounts;
      _sourceAccountId = _sourceAccounts.containsKey(_sourceAccountId)
          ? _sourceAccountId
          : _sourceAccounts.keys.firstOrNull;
      _destinationInvestmentId =
          investissements.containsKey(_destinationInvestmentId)
          ? _destinationInvestmentId
          : investissements.keys.firstOrNull;
      _destinationAccountId = _destinationInvestmentId == null
          ? null
          : _investmentHoldingAccounts[_destinationInvestmentId];
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

  List<DropdownMenuItem<String>> _buildDropdownItems(Map<String, String> data) {
    return data.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final destinationAccountId = _destinationInvestmentId == null
        ? null
        : _investmentHoldingAccounts[_destinationInvestmentId];
    if (_sourceAccountId == null ||
        destinationAccountId == null ||
        _destinationInvestmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Veuillez selectionner les comptes et un investissement.',
            ),
          ),
        ),
      );
      return;
    }

    if (_sourceAccounts.isEmpty ||
        _supportAccounts.isEmpty ||
        _investments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Aucun compte ou investissement disponible.'),
          ),
        ),
      );
      return;
    }

    if (_sourceAccountId == destinationAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Le compte source et le compte destination doivent etre differents.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final userId = LocalAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isSaving = false);
      return;
    }

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

    final transaction = TransactionModel(
      id: widget.existingTransaction?.id,
      amount: montant,
      date: _selectedDate,
      description: 'Investissement',
      type: 'investment',
      fromAccountId: _sourceAccountId,
      toAccountId: destinationAccountId,
      investmentId: _destinationInvestmentId,
    );

    try {
      final service = BudgetService(userId: userId);
      if (widget.existingTransaction == null) {
        await service.addTransaction(transaction);
      } else {
        await service.updateTransaction(
          widget.existingTransaction!,
          transaction,
        );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context).currency;

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
                  icon: Icons.trending_up_outlined,
                  title: context.tr('Nouvel investissement'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Montant'),
                    prefixIcon: const Icon(Icons.attach_money),
                    suffixText: currency,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return context.tr('Entrer un montant');
                    }
                    final parsed = double.tryParse(v.replaceAll(',', '.'));
                    if (parsed == null) return context.tr('Montant invalide');
                    return null;
                  },
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 10),
                    Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    TextButton(
                      onPressed: _pickDate,
                      child: Text(context.tr('Changer la date')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _sourceAccountId,
                  items: _buildDropdownItems(_sourceAccounts),
                  onChanged: (v) {
                    setState(() {
                      _sourceAccountId = v;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: context.tr('Compte source'),
                    prefixIcon: const Icon(Icons.account_balance_wallet),
                  ),
                  validator: (v) =>
                      v == null ? context.tr('Choisir un compte source') : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: _destinationInvestmentId,
                  items: _buildDropdownItems(_investments),
                  onChanged: (v) => setState(() {
                    _destinationInvestmentId = v;
                    _destinationAccountId = v == null
                        ? null
                        : _investmentHoldingAccounts[v];
                  }),
                  decoration: InputDecoration(
                    labelText: context.tr('Destination (action, fonds...)'),
                    prefixIcon: const Icon(Icons.trending_up),
                  ),
                  validator: (v) {
                    if (v == null)
                      return context.tr('Choisir un investissement');
                    if (!_investmentHoldingAccounts.containsKey(v)) {
                      return context.tr('Compte de detention manquant');
                    }
                    return null;
                  },
                ),
                if (_destinationInvestmentId != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${context.tr('Compte de detention')} : ${_supportAccounts[_investmentHoldingAccounts[_destinationInvestmentId]] ?? context.tr('Compte inconnu')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
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
                          label: Text(context.tr('Enregistrer')),
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
      ),
    );
  }
}
