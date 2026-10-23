import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/screens/profile/add_investment_page.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/security_gate.dart';

class InvestmentPage extends StatefulWidget {
  final String userId;
  const InvestmentPage({super.key, required this.userId});

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static const _allType = 'all';

  List<String> get _tabs => [
    _allType,
    ...investmentTypeOptions.map((option) => option.value),
  ];

  CollectionReference<Map<String, dynamic>> get _investmentsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('investments');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _accountsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('accounts');
  }

  Future<void> _openAddInvestment({DocumentSnapshot? doc}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddInvestmentPage(
          userId: widget.userId,
          existingData: doc?.data() as Map<String, dynamic>?,
          investmentId: doc?.id,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmDelete(_InvestmentViewModel investment) async {
    final isUsed = await BudgetService(
      userId: widget.userId,
    ).isInvestmentInUse(investment.id);
    if (!mounted) return;

    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Cet investissement est utilise ou possede encore un solde.',
            ),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Supprimer l investissement')),
          content: Text(
            'Supprimer "${investment.name}" ? Les transactions existantes ne seront pas supprimees.',
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
      message: context.tr(
        'Confirmez votre PIN avant de supprimer cet investissement.',
      ),
    );
    if (!authorized || !mounted) return;

    await _investmentsRef.doc(investment.id).delete();
    if (!mounted) return;
    context.read<UserDataProvider>().invalidateReferences();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Gestion des investissements')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((type) {
            final option = type == _allType ? null : investmentTypeOption(type);
            return Tab(
              icon: Icon(
                type == _allType ? Icons.grid_view_rounded : option!.icon,
              ),
              text: context.tr(type == _allType ? 'Tous' : option!.label),
            );
          }).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddInvestment(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Actif')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _accountsRef.snapshots(),
        builder: (context, accountSnapshot) {
          final Map<String, String> accounts = {
            for (final doc in accountSnapshot.data?.docs ?? [])
              doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _investmentsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('${context.tr('Erreur')} : ${snapshot.error}'),
                );
              }

              final investments = (snapshot.data?.docs ?? []).map((doc) {
                return _InvestmentViewModel.fromFirestore(doc, accounts);
              }).toList()..sort((a, b) => b.balance.compareTo(a.balance));

              final total = investments.fold(0.0, (sum, investment) {
                return sum + investment.balance;
              });

              if (investments.isEmpty) {
                return _buildEmptyState();
              }

              return TabBarView(
                controller: _tabController,
                children: _tabs.map((type) {
                  final filtered = type == _allType
                      ? investments
                      : investments.where((investment) {
                          return investment.investmentType == type;
                        }).toList();
                  final filteredTotal = filtered.fold(0.0, (sum, investment) {
                    return sum + investment.balance;
                  });

                  if (filtered.isEmpty) {
                    return _buildEmptyState(type: type);
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      _buildHeader(
                        count: filtered.length,
                        total: filteredTotal,
                        currency: currency,
                        privacy: privacy,
                      ),
                      const SizedBox(height: 16),
                      ...filtered.map(
                        (investment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildInvestmentCard(
                            investment: investment,
                            total: filteredTotal,
                            currency: currency,
                            privacy: privacy,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required int count,
    required double total,
    required String currency,
    required PrivacyProvider privacy,
  }) {
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
              Icons.area_chart_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Portefeuille investi'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count actif${count > 1 ? 's' : ''} - Total ${privacy.money(total, currency)}',
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

  Widget _buildInvestmentCard({
    required _InvestmentViewModel investment,
    required double total,
    required String currency,
    required PrivacyProvider privacy,
  }) {
    final share = total <= 0
        ? 0.0
        : (investment.balance / total).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  investment.typeOption.icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(flex: 0, child: _typeBadge(investment)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            investment.description.isEmpty
                                ? investment.holdingAccountName
                                : '${investment.description} - ${investment.holdingAccountName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.62),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAddInvestment(doc: investment.snapshot);
                  } else if (value == 'delete') {
                    _confirmDelete(investment);
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
                        const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
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
                  privacy.money(investment.balance, currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: privacy.hideAmounts
                        ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.58)
                        : Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                privacy.percent(share * 100),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.64),
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

  Widget _typeBadge(_InvestmentViewModel investment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.tr(investment.typeOption.label),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState({String type = _allType}) {
    final isFiltered = type != _allType;
    final option = isFiltered ? investmentTypeOption(type) : null;

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
                Icons.trending_up_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isFiltered
                  ? '${context.tr('Aucun actif')} ${context.tr(option!.label)}'
                  : context.tr('Aucun actif'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                isFiltered
                    ? 'Ajoutez un actif dans cette categorie pour le retrouver ici.'
                    : 'Ajoutez OR, ETF, crypto ou tout autre support pour suivre votre portefeuille.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.65),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => _openAddInvestment(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Ajouter un actif')),
            ),
          ],
        ),
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
}

class _InvestmentViewModel {
  final String id;
  final String name;
  final String description;
  final String investmentType;
  final double balance;
  final String holdingAccountName;
  final DocumentSnapshot? snapshot;

  InvestmentTypeOption get typeOption => investmentTypeOption(investmentType);

  const _InvestmentViewModel({
    required this.id,
    required this.name,
    required this.description,
    required this.investmentType,
    required this.balance,
    required this.holdingAccountName,
    this.snapshot,
  });

  factory _InvestmentViewModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, String> accounts,
  ) {
    final data = doc.data();
    final holdingAccountId = data['holdingAccountId'];

    return _InvestmentViewModel(
      id: doc.id,
      name: data['name'] ?? 'Sans nom',
      description: data['description'] ?? '',
      investmentType: (data['investmentType'] ?? 'other').toString(),
      balance: (data['balance'] ?? 0).toDouble(),
      holdingAccountName: accounts[holdingAccountId] ?? 'Compte non defini',
      snapshot: doc,
    );
  }
}
