import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/settings/currency_provider.dart';

class AddAccountPage extends StatefulWidget {
  final String userId;
  final String? accountId;
  final Map<String, dynamic>? existingData;

  const AddAccountPage({
    super.key,
    required this.userId,
    this.accountId,
    this.existingData,
  });

  @override
  State<AddAccountPage> createState() => _AddAccountPageState();
}

class _AddAccountPageState extends State<AddAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  bool _managedByInvestments = false;
  bool _isSaving = false;

  bool get _isEditing => widget.accountId != null;

  double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double _parseMoney(String value) {
    return _roundMoney(double.tryParse(value.trim().replaceAll(',', '.')) ?? 0);
  }

  Future<double> _investmentBalanceForAccount(String accountId) async {
    final snapshot = await DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('investments')
        .where('holdingAccountId', isEqualTo: accountId)
        .get();

    final total = snapshot.docs.fold<double>(0, (total, doc) {
      return total + ((doc.data()['balance'] ?? 0) as num).toDouble();
    });
    return _roundMoney(total);
  }

  @override
  void initState() {
    super.initState();

    final data = widget.existingData;
    if (data != null) {
      _nameCtrl.text = data['name'] ?? '';
      _descCtrl.text = data['description'] ?? '';
      _balanceCtrl.text =
          ((data['balance'] ?? 0) as num).toDouble().toStringAsFixed(2);
      _managedByInvestments = data['managedByInvestments'] == true;
    }
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameCtrl.text.trim().toUpperCase();
    final desc = _descCtrl.text.trim();
    final data = <String, dynamic>{
      'name': name,
      'description': desc,
      'managedByInvestments': _managedByInvestments,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('accounts');

    try {
      if (_isEditing) {
        if (_managedByInvestments) {
          data['balance'] = await _investmentBalanceForAccount(
            widget.accountId!,
          );
        } else {
          data['balance'] = _parseMoney(_balanceCtrl.text);
        }
        await ref.doc(widget.accountId).update(data);
      } else {
        data['balance'] = _managedByInvestments
            ? 0.0
            : _parseMoney(_balanceCtrl.text);
        data['createdAt'] = FieldValue.serverTimestamp();
        await ref.add(data);
      }

      if (!mounted) return;
      final userData = context.read<UserDataProvider>();
      userData.invalidateReferences();
      userData.markFinancialDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Compte enregistre'))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.tr('Erreur')} : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? context.tr('Modifier le compte') : context.tr('Nouveau compte'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildHeader(currency),
            const SizedBox(height: 18),
            _buildForm(currency),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAccount,
                icon: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isEditing ? context.tr('Mettre a jour') : context.tr('Ajouter')),
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

  Widget _buildHeader(String currency) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? context.tr('Ajuster le compte') : context.tr('Ajouter un compte'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context
                      .tr('Le solde sera affiche avec la devise {currency} dans toute l application.')
                      .replaceAll('{currency}', currency),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.64),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(String currency) {
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
                labelText: context.tr('Nom du compte'),
                hintText: context.tr('Ex: BOURSORAMA'),
                prefixIcon: const Icon(Icons.account_balance),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Entrez un nom de compte');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Description'),
                hintText: context.tr('Ex: Compte courant principal'),
                prefixIcon: const Icon(Icons.notes_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _managedByInvestments,
                onChanged: (value) {
                  setState(() {
                    _managedByInvestments = value;
                    if (value && !_isEditing) {
                      _balanceCtrl.text = '0';
                    }
                  });
                },
                title: Text(context.tr('Compte gere par les investissements')),
                subtitle: Text(
                  context.tr(
                    'Le solde de ce compte sera calcule depuis les actifs.',
                  ),
                ),
              ),
            ),
            if (_managedByInvestments) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.16),
                  ),
                ),
                child: Text(
                  context.tr(
                    'Un compte auto gere ne peut pas etre modifie directement. Son solde evolue uniquement avec la valeur des actifs et les operations d investissement.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _balanceCtrl,
              enabled: !_managedByInvestments,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: _isEditing
                    ? context.tr('Solde actuel')
                    : context.tr('Solde initial'),
                hintText: '0.00',
                suffixText: currency,
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (_managedByInvestments) return null;
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Entrez un solde');
                }
                final parsed = double.tryParse(
                  value.trim().replaceAll(',', '.'),
                );
                if (parsed == null) return context.tr('Solde invalide');
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.24),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.10),
      ),
    );
  }
}
