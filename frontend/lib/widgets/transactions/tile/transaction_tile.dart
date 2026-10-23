import 'package:mysold/widgets/app_design.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mysold/services/budget_service.dart';
import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/widgets/transactions/dialog/add_transaction_dialog.dart';

class TransactionTile extends StatelessWidget {
  final TransactionModel t;
  final VoidCallback onChanged;
  final Map<String, Map<String, dynamic>> categories;
  final Map<String, String> accounts;

  const TransactionTile({
    super.key,
    required this.t,
    required this.onChanged,
    this.categories = const {},
    this.accounts = const {},
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final formattedDate = DateFormat('dd/MM/yyyy').format(t.date);
    final data = t.categoryId == null ? null : categories[t.categoryId];
    final categoryName = data?['name'] ?? context.tr('Autre');
    final categoryColor = data?['color'] != null
        ? Color(data!['color'])
        : Colors.grey;
    final categoryIcon = data?['icon'] != null
        ? IconData(data!['icon'], fontFamily: 'MaterialIcons')
        : Icons.category;
    final accountName =
        accounts[t.fromAccountId] ?? context.tr('Compte inconnu');
    final amountText =
        "${t.type == 'expense' ? '-' : '+'}${privacy.money(t.amount, currency)}";
    final subtitleText = '$accountName - $categoryName - $formattedDate';
    return AppOperationCard(
      title: t.description,
      subtitle: subtitleText,
      amount: amountText,
      icon: categoryIcon,
      color: categoryColor,
      onTap: () => _showOptions(context),
    );
  }

  void _showOptions(BuildContext context) {
    final currency = context.read<CurrencyProvider>().currency;
    final privacy = context.read<PrivacyProvider>();
    final data = t.categoryId == null ? null : categories[t.categoryId];
    final categoryName = data?['name'] ?? context.tr('Autre');
    final formattedDate = DateFormat('dd/MM/yyyy').format(t.date);
    final accountName =
        accounts[t.fromAccountId] ?? context.tr('Compte inconnu');
    final accountLabel = t.type == 'income'
        ? context.tr('Compte crédité')
        : context.tr('Compte débité');

    showAppSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.description,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                _detailRow(context, context.tr('Type'), context.trType(t.type)),
                _detailRow(context, context.tr('Date'), formattedDate),
                _detailRow(context, context.tr('Categorie'), categoryName),
                _detailRow(context, accountLabel, accountName),
                _detailRow(
                  context,
                  context.tr('Montant'),
                  privacy.money(t.amount, currency),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.tr('Modifier')),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final result = await showDialog(
                            context: context,
                            builder: (_) =>
                                AddTransactionDialog(existingTransaction: t),
                          );
                          if (result == true) onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.delete_outline),
                        label: Text(context.tr('Supprimer')),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Supprimer')),
        content: Text(
          context.tr('Voulez-vous vraiment supprimer cette transaction ?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Annuler')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (t.id != null) {
                final userId = LocalAuth.instance.currentUser?.uid;
                if (userId == null) return;
                await BudgetService(userId: userId).deleteTransaction(t);
                context.read<UserDataProvider>().markFinancialDataChanged();
                onChanged();
              }
            },
            child: Text(
              context.tr('Supprimer'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
