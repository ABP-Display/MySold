import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:mysold/data/document_store.dart';

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
          child: Text(context.tr('Transfert')),
          onPressed: () {
            Navigator.pop(ctx);
            showDialog(
              context: context,
              builder: (_) => const AddTransferDialog(),
            );
          },
        ),
      ],
    ),
  );
}

/// --- TRANSFERT ---
class AddTransferDialog extends StatefulWidget {
  final TransactionModel? existingTransfer;

  const AddTransferDialog({super.key, this.existingTransfer});

  @override
  State<AddTransferDialog> createState() => _AddTransferDialogState();
}

class _AddTransferDialogState extends State<AddTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _sourceAccountId;
  String? _destinationAccountId;
  String? _sourceInvestmentId;
  bool _isInvestmentWithdrawal = false;

  TransactionModel? get _oldTransaction => widget.existingTransfer;

  Map<String, String> _accounts = {};
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
    _loadDropdownData();
    if (_oldTransaction != null) {
      _amountCtrl.text = _oldTransaction!.amount.toStringAsFixed(2);
      _selectedDate = _oldTransaction!.date;
      _sourceAccountId = _oldTransaction!.fromAccountId;
      _destinationAccountId = _oldTransaction!.toAccountId;
      _sourceInvestmentId = _oldTransaction!.investmentId;
      _isInvestmentWithdrawal = _sourceInvestmentId != null;
    }
  }

  Future<void> _loadDropdownData() async {
    final userId = LocalAuth.instance.currentUser?.uid;
    if (userId == null) return;
    final comptes = await context.read<UserDataProvider>().getManualAccounts();
    final investmentsSnapshot = await DocumentStore.instance
        .collection('users')
        .doc(userId)
        .collection('investments')
        .get();
    final investments = {
      for (final doc in investmentsSnapshot.docs)
        doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
    };
    final holdingAccounts = {
      for (final doc in investmentsSnapshot.docs)
        if ((doc.data()['holdingAccountId'] ?? '').toString().isNotEmpty)
          doc.id: doc.data()['holdingAccountId'].toString(),
    };

    if (!mounted) return;
    setState(() {
      _accounts = comptes;
      _investments = investments;
      _investmentHoldingAccounts = holdingAccounts;
      _sourceAccountId ??= comptes.keys.firstOrNull;
      _destinationAccountId ??= comptes.keys.length > 1
          ? comptes.keys.elementAt(1)
          : comptes.keys.firstOrNull;
      _sourceInvestmentId = investments.containsKey(_sourceInvestmentId)
          ? _sourceInvestmentId
          : investments.keys.firstOrNull;
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
    if (_isInvestmentWithdrawal) {
      await _saveInvestmentWithdrawal();
      return;
    }

    if (_sourceAccountId == null || _destinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Selectionnez deux comptes valides.')),
        ),
      );
      return;
    }
    if (_sourceAccountId == _destinationAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Les comptes doivent etre differents')),
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
      if (_oldTransaction == null) {
        await service.addTransfer(
          amount: montant,
          date: _selectedDate,
          sourceAccountId: _sourceAccountId!,
          destinationAccountId: _destinationAccountId!,
        );
      } else {
        final updated = _oldTransaction!.copyWith(
          amount: montant,
          date: _selectedDate,
          fromAccountId: _sourceAccountId!,
          toAccountId: _destinationAccountId!,
        );

        await service.updateTransfer(_oldTransaction!, updated);
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

  Future<void> _saveInvestmentWithdrawal() async {
    if (_sourceInvestmentId == null || _destinationAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Selectionnez un investissement et un compte valides.'),
          ),
        ),
      );
      return;
    }
    if (!_investmentHoldingAccounts.containsKey(_sourceInvestmentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Compte de detention manquant'))),
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
      if (_oldTransaction == null) {
        await service.addInvestmentWithdrawal(
          amount: montant,
          date: _selectedDate,
          investmentId: _sourceInvestmentId!,
          destinationAccountId: _destinationAccountId!,
        );
      } else {
        final updated = _oldTransaction!.copyWith(
          amount: montant,
          date: _selectedDate,
          fromAccountId: _investmentHoldingAccounts[_sourceInvestmentId!],
          toAccountId: _destinationAccountId!,
          investmentId: _sourceInvestmentId!,
          description: 'Retrait investissement',
          type: 'transfer',
        );
        await service.updateInvestmentWithdrawal(_oldTransaction!, updated);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existingTransfer == null
                      ? context.tr('Nouveau transfert')
                      : context.tr('Modifier le transfert'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.existingTransfer == null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(context.tr('Compte a compte')),
                          selected: !_isInvestmentWithdrawal,
                          onSelected: (_) => setState(() {
                            _isInvestmentWithdrawal = false;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(context.tr('Actif vers compte')),
                          selected: _isInvestmentWithdrawal,
                          onSelected: (_) => setState(() {
                            _isInvestmentWithdrawal = true;
                            _destinationAccountId ??=
                                _accounts.keys.firstOrNull;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.tr('Montant'),
                    prefixIcon: const Icon(Icons.euro),
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
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.date_range),
                    const SizedBox(width: 10),
                    Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                    const Spacer(),
                    TextButton(
                      onPressed: _pickDate,
                      child: Text(context.tr('Changer la date')),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isInvestmentWithdrawal)
                  DropdownButtonFormField<String>(
                    value: _investments.containsKey(_sourceInvestmentId)
                        ? _sourceInvestmentId
                        : null,
                    hint: Text(context.tr('Selectionner un investissement')),
                    items: _investments.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _sourceInvestmentId = v),
                    validator: (v) {
                      if (v == null) {
                        return context.tr('Choisir un investissement');
                      }
                      if (!_investmentHoldingAccounts.containsKey(v)) {
                        return context.tr('Compte de detention manquant');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: context.tr('Actif source'),
                      prefixIcon: const Icon(Icons.trending_down),
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: _accounts.containsKey(_sourceAccountId)
                        ? _sourceAccountId
                        : null,
                    hint: Text(context.tr('Selectionner un compte')),
                    items: _accounts.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _sourceAccountId = v;
                        if (_destinationAccountId == v) {
                          _destinationAccountId = null;
                        }
                      });
                    },
                    validator: (v) => v == null
                        ? context.tr('Choisir un compte source')
                        : null,
                    decoration: InputDecoration(
                      labelText: context.tr('Compte source'),
                      prefixIcon: const Icon(Icons.account_balance_wallet),
                    ),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _accounts.containsKey(_destinationAccountId)
                      ? _destinationAccountId
                      : null,
                  hint: Text(context.tr('Selectionner un compte')),
                  items: _accounts.entries
                      .where(
                        (e) =>
                            _isInvestmentWithdrawal ||
                            e.key != _sourceAccountId,
                      )
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _destinationAccountId = v),
                  validator: (v) => v == null
                      ? context.tr('Choisir un compte destination')
                      : null,
                  decoration: InputDecoration(
                    labelText: context.tr('Compte destination'),
                    prefixIcon:
                        const Icon(Icons.account_balance_wallet_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                if (!_isInvestmentWithdrawal && _accounts.length < 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      context.tr(
                        "Vous avez besoin d'au moins deux comptes pour effectuer un transfert.",
                      ),
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),
                if (_isInvestmentWithdrawal && _investments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      context.tr(
                        "Vous avez besoin d'au moins un investissement configure.",
                      ),
                      style: TextStyle(color: Colors.red[700]),
                    ),
                  ),

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
