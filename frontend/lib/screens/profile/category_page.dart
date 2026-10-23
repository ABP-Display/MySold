import 'package:mysold/widgets/app_design.dart';
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

class _CategoriePageState extends State<CategoriePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _openAddCategorie({DocumentSnapshot? doc}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCategoryPage(
          userId: widget.userId,
          existingData: doc?.data() as Map<String, dynamic>?,
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
    return Scaffold(
      appBar: appPageBar(
        context,
        title: Text(context.tr('Gestion des categories')),
        bottom: TabBar(
          controller: _tabController,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          tabs: [
            Tab(text: context.tr('Depenses')),
            Tab(text: context.tr('Revenus')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddCategorie(),
        icon: const Icon(Icons.add),
        label: Text(context.tr('Categorie')),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildTabContent('expense'), _buildTabContent('income')],
      ),
    );
  }

  Widget _buildTabContent(String type) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final isExpense = type == 'expense';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _categoriesRef.where('type', isEqualTo: type).snapshots(),
      builder: (context, categorySnapshot) {
        if (categorySnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (categorySnapshot.hasError) {
          return Center(
            child: Text('${context.tr('Erreur')} : ${categorySnapshot.error}'),
          );
        }

        final categories = (categorySnapshot.data?.docs ?? []).map((doc) {
          final data = doc.data();
          return _CategoryViewModel.fromFirestore(doc.id, data, doc);
        }).toList()..sort((a, b) => a.name.compareTo(b.name));

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _transactionsRef.where('type', isEqualTo: type).snapshots(),
          builder: (context, transactionSnapshot) {
            if (transactionSnapshot.hasError) {
              return Center(
                child: Text(
                  '${context.tr('Erreur')} : ${transactionSnapshot.error}',
                ),
              );
            }

            final totals = <String, double>{};
            final counts = <String, int>{};
            for (final doc in transactionSnapshot.data?.docs ?? []) {
              final data = doc.data();
              final categoryId = data['categoryId'] as String?;
              if (categoryId == null) continue;

              totals[categoryId] =
                  (totals[categoryId] ?? 0) + (data['amount'] ?? 0).toDouble();
              counts[categoryId] = (counts[categoryId] ?? 0) + 1;
            }

            final totalAmount = categories.fold(0.0, (sum, category) {
              return sum + (totals[category.id] ?? 0);
            });

            if (categories.isEmpty) {
              return _buildEmptyState(isExpense);
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                _buildHeader(
                  isExpense: isExpense,
                  count: categories.length,
                  totalAmount: totalAmount,
                  currency: currency,
                  privacy: privacy,
                ),
                const SizedBox(height: 16),
                ...categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCategoryCard(
                      category: category,
                      amount: totals[category.id] ?? 0,
                      transactionCount: counts[category.id] ?? 0,
                      totalAmount: totalAmount,
                      currency: currency,
                      isExpense: isExpense,
                      privacy: privacy,
                    ),
                  ),
                ),
              ],
            );
          },
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
    _tabController.dispose();
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
