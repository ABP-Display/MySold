import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/providers/user_data_provider.dart';

class AddInvestmentPage extends StatefulWidget {
  final String userId;
  final String? investmentId;
  final Map<String, dynamic>? existingData;

  const AddInvestmentPage({
    super.key,
    required this.userId,
    this.investmentId,
    this.existingData,
  });

  @override
  State<AddInvestmentPage> createState() => _AddInvestmentPageState();
}

class _AddInvestmentPageState extends State<AddInvestmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  String? _holdingAccountId;
  String? _initialHoldingAccountId;
  String _investmentType = 'other';
  double _initialBalance = 0;
  bool _isSaving = false;

  bool get _isEditing => widget.investmentId != null;

  double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  double _parseMoney(String value) {
    return _roundMoney(double.tryParse(value.trim().replaceAll(',', '.')) ?? 0);
  }

  CollectionReference<Map<String, dynamic>> get _accountsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('accounts');
  }

  @override
  void initState() {
    super.initState();

    final data = widget.existingData;
    if (data != null) {
      _nameCtrl.text = data['name'] ?? '';
      _descCtrl.text = data['description'] ?? '';
      _holdingAccountId = data['holdingAccountId'];
      _initialHoldingAccountId = _holdingAccountId;
      _investmentType = (data['investmentType'] ?? 'other').toString();
      _initialBalance = ((data['balance'] ?? 0) as num).toDouble();
      _balanceCtrl.text = _initialBalance.toStringAsFixed(2);
    }
  }

  Future<void> _saveInvestment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final balance = _parseMoney(_balanceCtrl.text);

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim(),
      'investmentType': _investmentType,
      'holdingAccountId': _holdingAccountId,
      'balance': balance,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final ref = DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('investments');

    try {
      final batch = DocumentStore.instance.batch();
      if (_isEditing) {
        final investmentRef = ref.doc(widget.investmentId);
        batch.update(investmentRef, data);

        if (_initialHoldingAccountId == _holdingAccountId) {
          final diff = _roundMoney(balance - _initialBalance);
          if (diff != 0 && _holdingAccountId != null) {
            batch.update(_accountsRef.doc(_holdingAccountId), {
              'balance': FieldValue.increment(diff),
            });
          }
        } else {
          if (_initialHoldingAccountId != null && _initialBalance != 0) {
            batch.update(_accountsRef.doc(_initialHoldingAccountId), {
              'balance': FieldValue.increment(-_initialBalance),
            });
          }
          if (_holdingAccountId != null && balance != 0) {
            batch.update(_accountsRef.doc(_holdingAccountId), {
              'balance': FieldValue.increment(balance),
            });
          }
        }
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        final investmentRef = ref.doc();
        batch.set(investmentRef, data);
        if (_holdingAccountId != null && balance != 0) {
          batch.update(_accountsRef.doc(_holdingAccountId), {
            'balance': FieldValue.increment(balance),
          });
        }
      }
      await batch.commit();

      if (!mounted) return;
      context.read<UserDataProvider>().invalidateReferences();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Investissement enregistre'))),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? context.tr('Modifier l investissement')
              : context.tr('Nouvel investissement'),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _accountsRef.snapshots(),
          builder: (context, snapshot) {
            final accounts = snapshot.data?.docs ?? [];
            final accountIds = accounts.map((account) => account.id).toSet();
            if (_holdingAccountId != null &&
                !accountIds.contains(_holdingAccountId)) {
              _holdingAccountId = null;
            }

            final managedAccounts = accounts.where((account) {
              return account.data()['managedByInvestments'] == true;
            }).toList();
            final supportAccounts = managedAccounts.isEmpty
                ? accounts
                : accounts.where((account) {
                    return account.data()['managedByInvestments'] == true ||
                        account.id == _holdingAccountId;
                  }).toList();
            if (_holdingAccountId == null && accounts.isNotEmpty) {
              _holdingAccountId = managedAccounts.isNotEmpty
                  ? managedAccounts.first.id
                  : accounts.first.id;
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildForm(supportAccounts),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveInvestment,
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
            );
          },
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.trending_up_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing
                      ? context.tr('Ajuster l actif')
                      : context.tr('Creer un actif'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr(
                    'Le montant evolue avec les operations d investissement.',
                  ),
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

  Widget _buildForm(List<QueryDocumentSnapshot<Map<String, dynamic>>> accounts) {
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
                labelText: context.tr('Nom de l investissement'),
                hintText: context.tr('Ex: OR, ETF WORLD, BTC'),
                prefixIcon: const Icon(Icons.show_chart_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Entrez un nom d investissement');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Description'),
                hintText: context.tr('Ex: Or physique ou ETF capitalisant'),
                prefixIcon: const Icon(Icons.notes_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _investmentType,
              items: investmentTypeOptions.map((option) {
                return DropdownMenuItem(
                  value: option.value,
                  child: Row(
                    children: [
                      Icon(option.icon, size: 18),
                      const SizedBox(width: 8),
                      Text(context.tr(option.label)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _investmentType = value);
              },
              decoration: InputDecoration(
                labelText: context.tr('Type d actif'),
                prefixIcon: const Icon(Icons.category_outlined),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _balanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: context.tr('Valeur actuelle de l actif'),
                hintText: '0.00',
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Entrez une valeur');
                }
                final parsed = double.tryParse(
                  value.trim().replaceAll(',', '.'),
                );
                if (parsed == null || parsed < 0) {
                  return context.tr('Valeur invalide');
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _holdingAccountId,
              items: accounts.map((account) {
                final data = account.data();
                final isManaged = data['managedByInvestments'] == true;
                final name = data['name'] ?? context.tr('Sans nom');
                final label = isManaged
                    ? '$name - ${context.tr('Auto')}'
                    : name.toString();
                return DropdownMenuItem(
                  value: account.id,
                  child: Text(label),
                );
              }).toList(),
              onChanged: (value) => setState(() => _holdingAccountId = value),
              decoration: InputDecoration(
                labelText: context.tr('Compte de detention'),
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null) return context.tr('Choisir un compte');
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }
}
