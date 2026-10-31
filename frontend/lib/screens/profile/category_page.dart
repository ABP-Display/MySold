import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/widgets/app_selection_button.dart';
import 'package:mysold/widgets/lazy_page_stack.dart';
import 'package:mysold/widgets/category_filter_bar.dart';
import 'package:mysold/widgets/category_amount_filter.dart';
import 'package:mysold/models/category_filter.dart';
import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/screens/profile/add_category_page.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/security_gate.dart';

class CategoriePage extends StatefulWidget {
  final String userId;
  const CategoriePage({super.key, required this.userId});

  @override
  State<CategoriePage> createState() => _CategoriePageState();
}

class _CategoriePageState extends State<CategoriePage> {
  int _selectedIndex = 0;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _categoryStream,
      _transactionStream;
  final _search = [TextEditingController(), TextEditingController()];
  final _minimum = <double?>[null, null], _maximum = <double?>[null, null];
  final _orders = [CategoryOrder.nameAscending, CategoryOrder.nameAscending];
  QuerySnapshot<Map<String, dynamic>>? _aggregatedSnapshot;
  final _totals = <String, double>{}, _counts = <String, int>{};

  CollectionReference<Map<String, dynamic>> get _categoriesRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get _transactionsRef {
    return DocumentStore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('transactions');
  }

  @override
  void initState() {
    super.initState();
    _createStreams();
  }

  void _createStreams() {
    _categoryStream = _categoriesRef.snapshots();
    _transactionStream = _transactionsRef.snapshots();
    _aggregatedSnapshot = null;
    _totals.clear();
    _counts.clear();
  }

  @override
  void didUpdateWidget(covariant CategoriePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      for (var i = 0; i < 2; i++) {
        _search[i].clear();
        _minimum[i] = null;
        _maximum[i] = null;
        _orders[i] = CategoryOrder.nameAscending;
      }
      _createStreams();
    }
  }

  Future<void> _openAmountFilter(int index) async {
    final result = await showAppSheet<CategoryAmountRange>(
      context: context,
      builder: (_) => CategoryAmountFilter(
        minimum: _minimum[index],
        maximum: _maximum[index],
      ),
    );
    if (mounted && result != null)
      setState(() {
        _minimum[index] = result.minimum;
        _maximum[index] = result.maximum;
      });
  }

  Future<void> _openAddCategorie({DocumentSnapshot? doc}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryPage(
          userId: widget.userId,
          existingData: doc?.data(),
          categoryId: doc?.id,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmDelete(_CategoryViewModel category) async {
    if (category.name.toLowerCase() == 'others') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('La categorie Others est protegee'))),
      );
      return;
    }

    final isUsed = await BudgetService(
      userId: widget.userId,
    ).isCategoryInUse(category.id);
    if (!mounted) return;

    if (isUsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Cette categorie est utilisee par des transactions.'),
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('Supprimer la categorie')),
          content: Text(
            'Supprimer "${category.name}" ? Les transactions existantes ne seront pas supprimees.',
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
        'Confirmez votre PIN avant de supprimer cette categorie.',
      ),
    );
    if (!authorized || !mounted) return;

    await _categoriesRef.doc(category.id).delete();
    if (!mounted) return;
    context.read<UserDataProvider>().invalidateReferences();
  }

  @override
  Widget build(BuildContext context) {
    final tabHeight = (MediaQuery.textScalerOf(context).scale(14) * 1.5 + 24)
        .clamp(52.0, 96.0)
        .toDouble();
    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(context.tr('Gestion des categories')),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabHeight),
          child: SizedBox(
            height: tabHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < 2; index++)
                  Expanded(
                    child: AppSelectionButton(
                      key: ValueKey('category-tab-$index'),
                      selected: index == _selectedIndex,
                      isTab: true,
                      outlined: false,
                      onPressed: () {
                        if (index != _selectedIndex)
                          setState(() => _selectedIndex = index);
                      },
                      child: Center(
                        child: Text(
                          context.tr(index == 0 ? 'Dépenses' : 'Revenus'),
                          style: const TextStyle(fontSize: 14, height: 1.2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCategorie(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Categorie')),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _categoryStream,
        builder: (context, categories) =>
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _transactionStream,
              builder: (context, transactions) {
                if (categories.hasError || transactions.hasError)
                  return Center(
                    child: Text(
                      '${context.tr('Erreur')} : ${categories.error ?? transactions.error}',
                    ),
                  );
                if (!categories.hasData || !transactions.hasData)
                  return const Center(child: CircularProgressIndicator());
                if (!identical(_aggregatedSnapshot, transactions.data)) {
                  _aggregatedSnapshot = transactions.data;
                  _totals.clear();
                  _counts.clear();
                  for (final doc in transactions.data!.docs) {
                    final data = doc.data();
                    if (data['type'] != 'income' && data['type'] != 'expense')
                      continue;
                    final reference = data['categoryId'];
                    final id = reference is DocumentReference
                        ? reference.id
                        : reference?.toString();
                    if (id == null || id.isEmpty) continue;
                    _totals[id] =
                        (_totals[id] ?? 0) +
                        (data['amount'] as num? ?? 0).toDouble();
                    _counts[id] = (_counts[id] ?? 0) + 1;
                  }
                }
                final models = categories.data!.docs
                    .map(
                      (doc) => _CategoryViewModel.fromFirestore(
                        doc.id,
                        doc.data(),
                        doc,
                      ),
                    )
                    .toList();
                return LazyPageStack(
                  index: _selectedIndex,
                  children: [
                    _buildTabContent('expense', models),
                    _buildTabContent('income', models),
                  ],
                );
              },
            ),
      ),
    );
  }

  Widget _buildTabContent(String type, List<_CategoryViewModel> models) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final isExpense = type == 'expense';
    final index = isExpense ? 0 : 1;
    final categories = models
        .where((category) => category.type == type)
        .toList();
    if (categories.isEmpty) return _buildEmptyState(isExpense);
    final total = categories.fold(
      0.0,
      (sum, category) => sum + (_totals[category.id] ?? 0),
    );
    final filter = CategoryFilter(
      query: _search[index].text,
      minimum: _minimum[index],
      maximum: _maximum[index],
      order: _orders[index],
    );
    final visible =
        categories
            .where(
              (category) =>
                  filter.matches(category.name, _totals[category.id] ?? 0),
            )
            .toList()
          ..sort(
            (a, b) => filter.compare(
              a.name,
              _totals[a.id] ?? 0,
              b.name,
              _totals[b.id] ?? 0,
            ),
          );
    return ListView.builder(
      key: PageStorageKey('category-list-$type'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: 2 + (visible.isEmpty ? 1 : visible.length),
      itemBuilder: (context, position) {
        if (position == 0)
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildHeader(
              isExpense: isExpense,
              count: categories.length,
              totalAmount: total,
              currency: currency,
              privacy: privacy,
            ),
          );
        if (position == 1)
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CategoryFilterBar(
              controller: _search[index],
              order: _orders[index],
              amountFiltered:
                  _minimum[index] != null || _maximum[index] != null,
              onSearch: (_) => setState(() {}),
              onOrder: (order) => setState(() => _orders[index] = order),
              onAmount: () => _openAmountFilter(index),
              onClearAmount: () => setState(() {
                _minimum[index] = null;
                _maximum[index] = null;
              }),
            ),
          );
        if (visible.isEmpty)
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr('Aucune catégorie ne correspond aux filtres.'),
              textAlign: TextAlign.center,
            ),
          );
        final category = visible[position - 2];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildCategoryCard(
            category: category,
            amount: _totals[category.id] ?? 0,
            transactionCount: _counts[category.id] ?? 0,
            totalAmount: total,
            currency: currency,
            isExpense: isExpense,
            privacy: privacy,
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required bool isExpense,
    required int count,
    required double totalAmount,
    required String currency,
    required PrivacyProvider privacy,
  }) {
    final color = isExpense ? Colors.redAccent : Colors.green;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              isExpense
                  ? Icons.trending_down_outlined
                  : Icons.trending_up_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    isExpense
                        ? 'Categories de depenses'
                        : 'Categories de revenus',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count categorie${count > 1 ? 's' : ''} - Total ${privacy.money(totalAmount, currency)}',
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

  Widget _buildCategoryCard({
    required _CategoryViewModel category,
    required double amount,
    required int transactionCount,
    required double totalAmount,
    required String currency,
    required bool isExpense,
    required PrivacyProvider privacy,
  }) {
    final share = totalAmount <= 0
        ? 0.0
        : (amount / totalAmount).clamp(0.0, 1.0).toDouble();

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
                  color: category.color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(category.icon, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$transactionCount transaction${transactionCount > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.62),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openAddCategorie(doc: category.snapshot);
                  } else if (value == 'delete') {
                    _confirmDelete(category);
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
                  privacy.money(amount, currency),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isExpense ? Colors.redAccent : Colors.green,
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
                : category.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isExpense) {
    return Center(
      child: SingleChildScrollView(
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
                Icons.category_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr(isExpense ? 'Aucune depense' : 'Aucun revenu'),
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Ajoutez une categorie pour organiser vos transactions.',
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
              onPressed: () => _openAddCategorie(),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Ajouter une categorie')),
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

  @override
  void dispose() {
    for (final controller in _search) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _CategoryViewModel {
  final String id;
  final String name;
  final String type;
  final Color color;
  final IconData icon;
  final DocumentSnapshot? snapshot;

  const _CategoryViewModel({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.snapshot,
  });

  factory _CategoryViewModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
    DocumentSnapshot snapshot,
  ) {
    return _CategoryViewModel(
      id: id,
      name: data['name'] ?? 'Sans nom',
      type: data['type'] ?? 'expense',
      color: Color(data['color'] ?? Colors.blue.value),
      icon: IconData(
        data['icon'] ?? Icons.category.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      snapshot: snapshot,
    );
  }
}
