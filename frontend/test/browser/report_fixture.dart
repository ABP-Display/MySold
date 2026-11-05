// Generates reports from synthetic data only, without API access.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/screens/profile/export_report_page.dart';
import 'package:mysold/services/transaction_export_service.dart';
import 'package:web/web.dart' as web;

TransactionModel tx(DateTime date, String type, double amount) =>
    TransactionModel(
      date: date,
      type: type,
      amount: amount,
      description: 'Opération de contrôle',
      fromAccountId: 'current',
      toAccountId: 'savings',
      categoryId: 'category',
    );

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  runApp(const MaterialApp(home: ExportReportPage()));
  try {
    for (final scenario in ['month', 'year', 'empty', 'single', 'negative']) {
      final start = scenario == 'year' ? DateTime(2026) : DateTime(2026, 10);
      final end = scenario == 'year'
          ? DateTime(2027)
          : scenario == 'single'
          ? DateTime(2026, 10, 2)
          : DateTime(2026, 11);
      final transactions = scenario == 'empty'
          ? <TransactionModel>[]
          : [
                  tx(
                    DateTime(2026, 10),
                    'income',
                    scenario == 'negative' ? 50 : 2500,
                  ),
                  for (var day = 2; day <= 28; day += 3)
                    tx(DateTime(2026, 10, day), 'expense', 42.35 + day * 3),
                  tx(DateTime(2026, 10, 10), 'investment', 400),
                  tx(DateTime(2026, 10, 15), 'transfer', 250),
                  tx(DateTime(2026, 10, 25), 'income', 150),
                ]
                .where(
                  (tx) => !tx.date.isBefore(start) && tx.date.isBefore(end),
                )
                .toList();
      final bytes = await TransactionExportService.buildPdfBytesInBackground(
        transactions: transactions,
        title: 'MySold - Rapport de contrôle - $scenario',
        currency: '€',
        accounts: {'current': 'Compte courant', 'savings': 'Épargne'},
        categories: {
          'category': {'name': 'Vie quotidienne'},
        },
        investments: {},
        periodStart: start,
        periodEnd: end,
      );
      web.document.body!.dataset['pdf$scenario'] = base64Encode(bytes);
    }
    web.document.body!.dataset['reportReady'] = 'true';
  } catch (error, stack) {
    web.document.body!.dataset['reportError'] = '$error\n$stack';
  }
}
