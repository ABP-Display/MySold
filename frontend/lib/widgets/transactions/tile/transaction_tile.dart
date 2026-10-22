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
    final subtitleStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.64),
          height: 1.25,
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      color: categoryColor.withOpacity(0.15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final subtitleWidth = _estimateSubtitleWidth(
            constraints.maxWidth,
            amountText,
          );
          final shouldWrapSubtitle = _textNeedsTwoLines(
            context,
            subtitleText,
            subtitleStyle,
            subtitleWidth,
          );

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: categoryColor.withOpacity(0.2),
              child: Icon(categoryIcon, color: categoryColor),
            ),
            title: Text(
              t.description,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            isThreeLine: shouldWrapSubtitle,
            subtitleTextStyle: subtitleStyle,
            subtitle: Text(
              subtitleText,
              maxLines: shouldWrapSubtitle ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              amountText,
              style: TextStyle(
                color: categoryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            onTap: () => _showOptions(context),
          );
        },
      ),
    );
  }

  double _estimateSubtitleWidth(double tileWidth, String amountText) {
    final estimatedAmountWidth =
        (amountText.length * 9.0).clamp(72.0, 130.0).toDouble();
    const horizontalPadding = 32.0;
    const leadingAndGap = 64.0;
    const trailingGap = 16.0;
    return (tileWidth -
            horizontalPadding -
            leadingAndGap -
            trailingGap -
            estimatedAmountWidth)
        .clamp(80.0, tileWidth)
        .toDouble();
  }

  bool _textNeedsTwoLines(
    BuildContext context,
    String text,
    TextStyle? style,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(style: style, text: text),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
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

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                ),
                Text(
                  t.description,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                _detailRow(
                  context,
                  context.tr('Type'),
                  context.trType(t.type),
                ),
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
