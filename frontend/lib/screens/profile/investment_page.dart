import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/annual_analysis_scope.dart';
import 'package:mysold/widgets/annual_entity_row.dart';
import 'package:mysold/screens/profile/entity_evolution_page.dart';
import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/investment_type.dart';
import 'package:mysold/screens/profile/add_investment_page.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/security_gate.dart';
import 'investment_categories_page.dart';
import 'investment_filter_dialog.dart';

class InvestmentPage extends StatefulWidget {
  final String userId;
  const InvestmentPage({super.key, required this.userId});

  @override
  State<InvestmentPage> createState() => _InvestmentPageState();
}

class _InvestmentPageState extends State<InvestmentPage> {
  List<InvestmentTypeOption> _typeOptions = investmentTypeOptions;
  Set<String> _selectedTypes = {};
  late Stream<QuerySnapshot<Map<String, dynamic>>> _accountsStream,
      _investmentsStream;

  CollectionReference<Map<String, dynamic>> get _investmentsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('investments');
  }

  @override
  void initState() {
    super.initState();
    _accountsStream = _accountsRef.snapshots();
    _investmentsStream = _investmentsRef.snapshots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _typeOptions = context.watch<UserDataProvider>().investmentCategories;
    _selectedTypes.retainAll(_typeOptions.map((o) => o.value));
  }

  Future<void> _openFilter() async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => InvestmentFilterDialog(
        options: _typeOptions,
        selected: _selectedTypes,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedTypes = selected.intersection(
        _typeOptions.map((o) => o.value).toSet(),
      );
    });
  }

  void _manageCategories(Set<String> usedTypes) {
    final provider = context.read<UserDataProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvestmentCategoriesPage(
          options: _typeOptions,
          usedTypes: usedTypes,
          onSave: provider.saveInvestmentCategories,
          createId: newDocumentId,
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant InvestmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _selectedTypes = {};
      _accountsStream = _accountsRef.snapshots();
      _investmentsStream = _investmentsRef.snapshots();
    }
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
          existingData: doc?.data(),
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
            context.trParams(
              'Supprimer « {name} » ? Les transactions existantes ne seront pas supprimées.',
              {'name': investment.name},
            ),
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
      appBar: appPageBar(
        context,
        title: Text(context.tr('Gestion des investissements')),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            FloatingActionButton(
              key: const ValueKey('investment-filter'),
              heroTag: 'investment-filter',
              tooltip: context.tr('Filtres'),
              onPressed: _openFilter,
              child: Badge(
                isLabelVisible: _selectedTypes.isNotEmpty,
                label: Text('${_selectedTypes.length}'),
                child: Icon(
                  _selectedTypes.isEmpty
                      ? Icons.filter_list
                      : Icons.filter_list_alt,
                ),
              ),
            ),
            FloatingActionButton.extended(
              onPressed: () => _openAddInvestment(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Actif')),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _accountsStream,
        builder: (context, accountSnapshot) {
          final Map<String, String> accounts = {
            for (final doc in accountSnapshot.data?.docs ?? [])
              doc.id: (doc.data()['name'] ?? 'Sans nom').toString(),
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _investmentsStream,
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
              final filtered = investments.where((investment) {
                return _selectedTypes.isEmpty ||
                    _selectedTypes.contains(
                      investmentTypeOption(
                        investment.investmentType,
                        options: _typeOptions,
                      ).value,
                    );
              }).toList();
              final filteredTotal = filtered.fold(
                0.0,
                (sum, investment) => sum + investment.balance,
              );

              return AnnualAnalysisScope(
                key: ValueKey(widget.userId),
                builder: (context, analysis) => ListView(
                  key: const PageStorageKey('investment-list'),
                  dragStartBehavior: DragStartBehavior.down,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: [
                    _buildHeader(
                      count: filtered.length,
                      total: filteredTotal,
                      currency: currency,
                      privacy: privacy,
                      usedTypes: investments
                          .map((i) => i.investmentType)
                          .toSet(),
                    ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty) _buildEmptyState(),
                    ...filtered.map(
                      (investment) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildInvestmentCard(
                          investment: investment,
                          analysis: analysis,
                          currency: currency,
                          privacy: privacy,
                        ),
                      ),
                    ),
                  ],
                ),
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
    required Set<String> usedTypes,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          IconButton(
            key: const ValueKey('manage-investment-categories'),
            tooltip: context.tr('Gérer les catégories d’investissement'),
            onPressed: () => _manageCategories(usedTypes),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentCard({
    required _InvestmentViewModel investment,
    required Map<String, Map<String, dynamic>> analysis,
    required String currency,
    required PrivacyProvider privacy,
  }) {
    final option = investmentTypeOption(
      investment.investmentType,
      options: _typeOptions,
    );
    return AnnualEntityRow(
      key: ValueKey('investment-${investment.id}'),
      name: investment.name,
      subtitle:
          '${investmentCategoryLabel(context, option)} · ${investment.holdingAccountName}',
      amount: annualEntityAmount(
        context,
        investment.balance,
        currency,
        hidden: privacy.hideAmounts,
      ),
      percent: analysis['investments/${investment.id}']?['percent'] as num?,
      hidden: privacy.hideAmounts,
      icon: option.icon,
      color: option.color,
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            settings: RouteSettings(name: '/investments/${investment.id}'),
            builder: (_) => EntityEvolutionPage(
              userId: widget.userId,
              entityPath: 'investments/${investment.id}',
              name: investment.name,
              onEdit: (doc) => _openAddInvestment(doc: doc),
            ),
          ),
        );
        if (mounted) setState(() {});
      },
      menu: EntityActionsMenu(
        onEdit: () => _openAddInvestment(doc: investment.snapshot),
        onDelete: () => _confirmDelete(investment),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _selectedTypes.isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 28, 28, 28),
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
            context.tr('Aucun actif'),
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
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
