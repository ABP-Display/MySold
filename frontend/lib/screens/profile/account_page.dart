import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/profile/add_account_page.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/security_gate.dart';

class ComptePage extends StatefulWidget {
  final String userId;
  const ComptePage({super.key, required this.userId});

  @override
  State<ComptePage> createState() => _ComptePageState();
}

class _ComptePageState extends State<ComptePage> {
  CollectionReference<Map<String, dynamic>> get _accountsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('accounts');
  }

  Future<void> _openAddCompte({DocumentSnapshot? doc}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAccountPage(
          userId: widget.userId,
          existingData: doc?.data() as Map<String, dynamic>?,
          accountId: doc?.id,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmDelete(_AccountViewModel account) async {
    final isUsed = await BudgetService(
      userId: widget.userId,
    ).isAccountInUse(account.id);
    if (!mounted) return;

    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Ce compte est utilise par des transactions ou investissements.'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Supprimer le compte')),
          content: Text(
            'Supprimer "${account.name}" ? Les transactions qui utilisent ce compte ne seront pas supprimees.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('Annuler')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr('Supprimer'),
                style: const TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final authorized = await SecurityGate.requestPin(
      context,
      title: context.tr('Suppression protegee'),
      message: context.tr('Confirmez votre PIN avant de supprimer ce compte.'),
    );
    if (!authorized || !mounted) return;

    await _accountsRef.doc(account.id).delete();
    if (!mounted) return;
    final userData = context.read<UserDataProvider>();
    userData.invalidateReferences();
    userData.markFinancialDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Gestion des comptes'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCompte(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Compte')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _accountsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('${context.tr('Erreur')} : ${snapshot.error}'));
          }

          final accounts = (snapshot.data?.docs ?? []).map((doc) {
            final data = doc.data();
            return _AccountViewModel(
              id: doc.id,
              name: data['name'] ?? 'Sans nom',
              description: data['description'] ?? '',
              balance: (data['balance'] ?? 0).toDouble(),
              managedByInvestments: data['managedByInvestments'] == true,
              snapshot: doc,
            );
          }).toList()
            ..sort((a, b) => b.balance.compareTo(a.balance));

          final totalBalance = accounts.fold(0.0, (sum, account) {
            return sum + account.balance;
          });

          if (accounts.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _buildHeader(accounts.length, totalBalance, currency, privacy),
              const SizedBox(height: 16),
              ...accounts.map(
                (account) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildAccountCard(
                    account: account,
                    totalBalance: totalBalance,
                    currency: currency,
                    privacy: privacy,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    int accountCount,
    double totalBalance,
    String currency,
    PrivacyProvider privacy,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Solde total'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.65),
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      privacy.money(totalBalance, currency),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$accountCount compte${accountCount > 1 ? 's' : ''} bancaire${accountCount > 1 ? 's' : ''}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard({
    required _AccountViewModel account,
    required double totalBalance,
    required String currency,
    required PrivacyProvider privacy,
  }) {
    final share = totalBalance <= 0
        ? 0.0
        : (account.balance / totalBalance).clamp(0.0, 1.0).toDouble();
    final color = privacy.hideAmounts
        ? Theme.of(context).colorScheme.onSurface.withOpacity(0.48)
        : account.balance >= 0
            ? Colors.green
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.account_balance, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    if (account.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.62),
                            ),
                      ),
                    ],
                    if (account.managedByInvestments) ...[
                      const SizedBox(height: 6),
                      Text(
                        context.tr('Compte investissement auto'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAddCompte(doc: account.snapshot);
                  } else if (value == 'delete') {
                    _confirmDelete(account);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined),
                        const SizedBox(width: 8),
                        Text(context.tr('Modifier')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, color: Colors.redAccent),
                        const SizedBox(width: 8),
                        Text(context.tr('Supprimer')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  privacy.money(account.balance, currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              Text(
                privacy.percent(share * 100),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.64),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: privacy.hideAmounts ? 1 : share,
            minHeight: 6,
            color: privacy.hideAmounts
                ? Theme.of(context).colorScheme.onSurface.withOpacity(0.18)
                : null,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr('Aucun compte'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Ajoutez votre premier compte bancaire pour commencer a suivre votre solde.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                  ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAddCompte(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Ajouter un compte')),
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

class _AccountViewModel {
  final String id;
  final String name;
  final String description;
  final double balance;
  final bool managedByInvestments;
  final DocumentSnapshot? snapshot;

  const _AccountViewModel({
    required this.id,
    required this.name,
    required this.description,
    required this.balance,
    required this.managedByInvestments,
    this.snapshot,
  });
}
