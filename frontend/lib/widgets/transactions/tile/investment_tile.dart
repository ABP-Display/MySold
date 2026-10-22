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
import 'package:mysold/widgets/transactions/dialog/add_investment_dialog.dart';

class InvestmentTransactionTile extends StatelessWidget {
  final TransactionModel t;
  final VoidCallback onChanged;
  final Map<String, String> accounts;
  final Map<String, String> investments;

  const InvestmentTransactionTile({
    super.key,
    required this.t,
    required this.onChanged,
    this.accounts = const {},
    this.investments = const {},
  });

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final formattedDate = DateFormat('dd/MM/yyyy').format(t.date);
    final source = accounts[t.fromAccountId] ?? context.tr('Compte source');
    final destination =
        accounts[t.toAccountId] ?? context.tr('Compte investissement');
    final investment = investments[t.investmentId] ?? context.tr('Investissement');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
          child: Icon(
            Icons.trending_up_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          '$source -> $destination',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('$investment\n$formattedDate'),
        isThreeLine: true,
        trailing: Text(
          '+${privacy.money(t.amount, currency)}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        onTap: () => _showOptions(context),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final currency = context.read<CurrencyProvider>().currency;
    final privacy = context.read<PrivacyProvider>();
    final formattedDate = DateFormat('dd/MM/yyyy').format(t.date);
    final source = accounts[t.fromAccountId] ?? context.tr('Compte source');
    final destination =
        accounts[t.toAccountId] ?? context.tr('Compte investissement');
    final investment = investments[t.investmentId] ?? context.tr('Investissement');

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
                  investment,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 14),
                _detailRow(context, context.tr('Date'), formattedDate),
                _detailRow(context, context.tr('Compte source'), source),
                _detailRow(context, context.tr('Compte support'), destination),
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
                                AddInvestmentDialog(existingTransaction: t),
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
        content: Text(context.tr('Supprimer cette operation investissement ?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('Annuler')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final userId = LocalAuth.instance.currentUser?.uid;
              if (userId == null) return;
              await BudgetService(userId: userId).deleteInvestment(t);
              context.read<UserDataProvider>().markFinancialDataChanged();
              onChanged();
            },
            child: Text(
              context.tr('Supprimer'),
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
