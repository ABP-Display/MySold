import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:mysold/models/transaction_model.dart';

class TransactionExportService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _generatedAtFormat = DateFormat('dd/MM/yyyy HH:mm');

  static Future<String?> saveCsv({
    required List<TransactionModel> transactions,
    required String title,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
  }) async {
    final csv = _buildCsv(
      transactions: transactions,
      currency: currency,
      accounts: accounts,
      categories: categories,
      investments: investments,
    );
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final baseName = _safeName(title);

    return FileSaver.instance.saveAs(
      name: baseName.isEmpty ? 'sold_up_export' : baseName,
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static Future<String?> savePdf({
    required List<TransactionModel> transactions,
    required String title,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
    int? primaryColor,
  }) async {
    final font = await _loadPdfFont('assets/fonts/Roboto-Regular.ttf');
    final boldFont = await _loadPdfFont('assets/fonts/Roboto-Bold.ttf');
    final logo = await _loadImage('assets/icons/app_icon_circle.png');
    final accent = _readableAccent(primaryColor ?? 0xFF2563EB);
    final bytes = await _buildPdfBytes(
      transactions: transactions,
      title: title,
      currency: currency,
      accounts: accounts,
      categories: categories,
      investments: investments,
      font: font,
      boldFont: boldFont,
      logo: logo,
      accent: accent,
    );
    final baseName = _safeName(title);

    return FileSaver.instance.saveAs(
      name: baseName.isEmpty ? 'sold_up_export' : baseName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Future<Uint8List> buildPdfBytesInBackground({
    required List<TransactionModel> transactions,
    required String title,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
    int? primaryColor,
  }) async {
    final regularFont = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final boldFont = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    Uint8List? logoBytes;
    try {
      final logo = await rootBundle.load('assets/icons/app_icon_circle.png');
      logoBytes = logo.buffer.asUint8List(
        logo.offsetInBytes,
        logo.lengthInBytes,
      );
    } catch (_) {
      logoBytes = null;
    }

    return compute(_buildPdfBytesIsolate, {
      'transactions': transactions.map(_transactionToPayload).toList(),
      'title': title,
      'currency': currency,
      'accounts': accounts,
      'categories': categories,
      'investments': investments,
      'primaryColor': primaryColor ?? 0xFF2563EB,
      'regularFont': regularFont.buffer.asUint8List(
        regularFont.offsetInBytes,
        regularFont.lengthInBytes,
      ),
      'boldFont': boldFont.buffer.asUint8List(
        boldFont.offsetInBytes,
        boldFont.lengthInBytes,
      ),
      'logo': logoBytes,
    });
  }

  static Future<String?> savePdfBytes({
    required Uint8List bytes,
    required String title,
  }) {
    final baseName = _safeName(title);
    return FileSaver.instance.saveAs(
      name: baseName.isEmpty ? 'sold_up_export' : baseName,
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static Map<String, dynamic> _transactionToPayload(TransactionModel tx) {
    return {
      'id': tx.id,
      'amount': tx.amount,
      'date': tx.date.millisecondsSinceEpoch,
      'description': tx.description,
      'type': tx.type,
      'categoryId': tx.categoryId,
      'fromAccountId': tx.fromAccountId,
      'toAccountId': tx.toAccountId,
      'investmentId': tx.investmentId,
    };
  }

  static TransactionModel _transactionFromPayload(Map<dynamic, dynamic> data) {
    return TransactionModel(
      id: data['id']?.toString(),
      amount: (data['amount'] as num).toDouble(),
      date: DateTime.fromMillisecondsSinceEpoch(data['date'] as int),
      description: data['description']?.toString() ?? '',
      type: data['type']?.toString() ?? '',
      categoryId: data['categoryId']?.toString(),
      fromAccountId: data['fromAccountId']?.toString(),
      toAccountId: data['toAccountId']?.toString(),
      investmentId: data['investmentId']?.toString(),
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required List<TransactionModel> transactions,
    required String title,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
    required pw.Font font,
    required pw.Font boldFont,
    required pw.ImageProvider? logo,
    required PdfColor accent,
  }) async {
    final income = _sumByType(transactions, 'income');
    final expense = _sumByType(transactions, 'expense');
    final investment = _sumByType(transactions, 'investment');
    final transfer = _sumByType(transactions, 'transfer');
    final net = income - expense;
    final available = income - expense - investment;
    final categoryTotals = _expenseCategoryTotals(transactions, categories);
    final typeTotals = {
      'income': income,
      'expense': expense,
      'investment': investment,
      'transfer': transfer,
      'available': available,
    };

    final document = pw.Document(
      title: title,
      author: 'MySold',
      creator: 'MySold',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        footer: (context) => _footer(context, font),
        build: (context) {
          return [
            _coverHeader(
              title: title,
              logo: logo,
              accent: accent,
              font: font,
              boldFont: boldFont,
            ),
            pw.SizedBox(height: 16),
            _summaryGrid(
              income: income,
              expense: expense,
              investment: investment,
              transfer: transfer,
              net: net,
              available: available,
              transactionCount: transactions.length,
              currency: currency,
              accent: accent,
              font: font,
              boldFont: boldFont,
            ),
            pw.SizedBox(height: 14),
            _sectionTitle('Vue budgétaire', accent, boldFont),
            pw.SizedBox(height: 8),
            _budgetSummary(
              income: income,
              expense: expense,
              investment: investment,
              available: available,
              net: net,
              currency: currency,
              font: font,
              boldFont: boldFont,
            ),
            pw.SizedBox(height: 14),
            _sectionTitle('Répartition du rapport', accent, boldFont),
            pw.SizedBox(height: 8),
            _typeBreakdown(
              totals: typeTotals,
              currency: currency,
              font: font,
              boldFont: boldFont,
              accent: accent,
            ),
            if (categoryTotals.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              _sectionTitle('Top catégories de dépenses', accent, boldFont),
              pw.SizedBox(height: 8),
              _categoryBreakdown(
                categoryTotals,
                expense,
                currency,
                font,
                boldFont,
                accent,
              ),
            ],
            pw.SizedBox(height: 14),
            _sectionTitle('Détail par type d opération', accent, boldFont),
            pw.SizedBox(height: 8),
            _transactionsByType(
              transactions: transactions,
              currency: currency,
              accounts: accounts,
              categories: categories,
              investments: investments,
              font: font,
              boldFont: boldFont,
              accent: accent,
            ),
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _coverHeader({
    required String title,
    required pw.ImageProvider? logo,
    required PdfColor accent,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (logo != null)
            pw.Container(
              width: 46,
              height: 46,
              child: pw.Image(logo),
            ),
          if (logo != null) pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MySold',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 20,
                    color: const PdfColor.fromInt(0xFF0F172A),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: const PdfColor.fromInt(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          pw.Container(width: 4, height: 46, color: accent),
        ],
      ),
    );
  }

  static pw.Widget _summaryGrid({
    required double income,
    required double expense,
    required double investment,
    required double transfer,
    required double net,
    required double available,
    required int transactionCount,
    required String currency,
    required PdfColor accent,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            _summaryCard(
              'Revenus',
              income,
              currency,
              const PdfColor.fromInt(0xFF16A34A),
              font,
              boldFont,
            ),
            pw.SizedBox(width: 8),
            _summaryCard(
              'Dépenses',
              expense,
              currency,
              const PdfColor.fromInt(0xFFDC2626),
              font,
              boldFont,
            ),
            pw.SizedBox(width: 8),
            _summaryCard(
              'Reste disponible',
              available,
              currency,
              available >= 0
                  ? const PdfColor.fromInt(0xFF16A34A)
                  : const PdfColor.fromInt(0xFFDC2626),
              font,
              boldFont,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _summaryCard('Investissements', investment, currency, accent, font, boldFont),
            pw.SizedBox(width: 8),
            _summaryCard(
              'Transferts',
              transfer,
              currency,
              const PdfColor.fromInt(0xFF64748B),
              font,
              boldFont,
            ),
            pw.SizedBox(width: 8),
            _summaryCard(
              'Operations',
              transactionCount.toDouble(),
              '',
              const PdfColor.fromInt(0xFF64748B),
              font,
              boldFont,
              decimals: 0,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _summaryCard(
    String label,
    double value,
    String currency,
    PdfColor color,
    pw.Font font,
    pw.Font boldFont, {
    bool highlighted = false,
    int decimals = 2,
  }) {
    final background = highlighted ? color : PdfColors.white;
    final textColor = highlighted ? PdfColors.white : color;
    final mutedColor = highlighted
        ? const PdfColor.fromInt(0xDDFFFFFF)
        : const PdfColor.fromInt(0xFF64748B);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: background,
          border: pw.Border.all(
            color: highlighted ? color : const PdfColor.fromInt(0xFFE5E7EB),
          ),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(font: font, fontSize: 8, color: mutedColor),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${value.toStringAsFixed(decimals)}${currency.isEmpty ? '' : ' $currency'}',
              style: pw.TextStyle(font: boldFont, fontSize: 12, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _budgetSummary({
    required double income,
    required double expense,
    required double investment,
    required double available,
    required double net,
    required String currency,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final hasIncome = income > 0;
    final used = expense + investment;
    final spentRatio = hasIncome
        ? (used / income).clamp(0.0, 1.0).toDouble()
        : used > 0
            ? 1.0
            : 0.0;
    final percentageLabel = hasIncome
        ? '${((used / income) * 100).toStringAsFixed(1)} %'
        : used > 0
        ? 'Sans revenu'
            : '0.0 %';
    final isOverBudget = hasIncome ? used > income : used > 0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF8FAFC),
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Utilisation du revenu disponible',
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: const PdfColor.fromInt(0xFF111827),
                ),
              ),
              pw.Text(
                percentageLabel,
                style: pw.TextStyle(
                  font: boldFont,
                  fontSize: 9,
                  color: isOverBudget
                      ? const PdfColor.fromInt(0xFFDC2626)
                      : const PdfColor.fromInt(0xFF16A34A),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _progressBar(spentRatio, const PdfColor.fromInt(0xFFDC2626)),
          pw.SizedBox(height: 8),
          pw.Text(
            'Dépenses: ${expense.toStringAsFixed(2)} $currency  |  Investissements: ${investment.toStringAsFixed(2)} $currency',
            style: pw.TextStyle(font: font, fontSize: 8, color: const PdfColor.fromInt(0xFF64748B)),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Solde net: ${net.toStringAsFixed(2)} $currency  |  Reste disponible: ${available.toStringAsFixed(2)} $currency',
            style: pw.TextStyle(font: boldFont, fontSize: 8, color: available >= 0 ? const PdfColor.fromInt(0xFF334155) : const PdfColor.fromInt(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _typeBreakdown({
    required Map<String, double> totals,
    required String currency,
    required pw.Font font,
    required pw.Font boldFont,
    required PdfColor accent,
  }) {
    final positiveValues = [
      totals['income'] ?? 0.0,
      totals['expense'] ?? 0.0,
      totals['investment'] ?? 0.0,
      totals['transfer'] ?? 0.0,
      (totals['available'] ?? 0.0).abs(),
      1.0,
    ];
    final maxValue = positiveValues.reduce((a, b) => a > b ? a : b);
    final entries = <MapEntry<String, double>>[
      MapEntry('Revenus', totals['income'] ?? 0.0),
      MapEntry('Dépenses', totals['expense'] ?? 0.0),
      MapEntry('Investissements', totals['investment'] ?? 0.0),
      MapEntry('Transferts', totals['transfer'] ?? 0.0),
      MapEntry('Reste disponible', totals['available'] ?? 0.0),
    ];

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: entries.map((entry) {
          final color = _reportColor(entry.key, entry.value, accent);
          final ratio = entry.value.abs() / maxValue;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.Container(width: 7, height: 7, color: color),
                pw.SizedBox(width: 7),
                pw.SizedBox(
                  width: 86,
                  child: pw.Text(
                    entry.key,
                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: const PdfColor.fromInt(0xFF111827)),
                  ),
                ),
                pw.Expanded(child: _progressBar(ratio, color)),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 72,
                  child: pw.Text(
                    '${entry.value.toStringAsFixed(2)} $currency',
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(font: boldFont, fontSize: 8, color: color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _categoryBreakdown(
    Map<String, double> totals,
    double totalExpense,
    String currency,
    pw.Font font,
    pw.Font boldFont,
    PdfColor accent,
  ) {
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.take(5).toList();

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE5E7EB)),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: topEntries.map((entry) {
          final ratio = totalExpense <= 0 ? 0.0 : (entry.value / totalExpense).clamp(0.0, 1.0);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      entry.key,
                      style: pw.TextStyle(font: font, fontSize: 8.5, color: const PdfColor.fromInt(0xFF111827)),
                    ),
                    pw.Text(
                      '${entry.value.toStringAsFixed(2)} $currency',
                      style: pw.TextStyle(font: boldFont, fontSize: 8, color: const PdfColor.fromInt(0xFF64748B)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                _progressBar(ratio, accent),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  static pw.Widget _transactionTable({
    required List<TransactionModel> transactions,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
    required pw.Font font,
    required pw.Font boldFont,
    required PdfColor accent,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: pw.BoxDecoration(color: accent),
        children: ['Date', 'Type', 'Description', 'Compte', 'Categorie / Actif', 'Montant']
            .map((text) => _tableHeaderCell(text, boldFont))
            .toList(),
      ),
      ...transactions.asMap().entries.map((entry) {
        final index = entry.key;
        final tx = entry.value;
        final amountPrefix = tx.type == 'income' ? '+' : tx.type == 'expense' ? '-' : '';
        final amountColor = tx.type == 'income'
            ? const PdfColor.fromInt(0xFF16A34A)
            : tx.type == 'expense'
                ? const PdfColor.fromInt(0xFFDC2626)
                : accent;

        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: index.isEven ? PdfColors.white : const PdfColor.fromInt(0xFFF8FAFC),
          ),
          children: [
            _tableCell(_dateFormat.format(tx.date), font),
            _tableCell(_typeLabel(tx.type), font),
            _tableCell(tx.description, font),
            _tableCell(_accountLabel(tx, accounts), font),
            _tableCell(_referenceLabel(tx, categories, investments), font),
            _tableCell(
              '$amountPrefix${tx.amount.abs().toStringAsFixed(2)} $currency',
              boldFont,
              color: amountColor,
              alignRight: true,
            ),
          ],
        );
      }),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE5E7EB), width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(48),
        1: pw.FixedColumnWidth(62),
        2: pw.FlexColumnWidth(1.4),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.1),
        5: pw.FixedColumnWidth(76),
      },
      children: rows,
    );
  }

  static pw.Widget _transactionsByType({
    required List<TransactionModel> transactions,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
    required pw.Font font,
    required pw.Font boldFont,
    required PdfColor accent,
  }) {
    final order = ['income', 'expense', 'investment', 'transfer'];
    final sections = <pw.Widget>[];
    for (final type in order) {
      final typed = transactions.where((tx) => tx.type == type).toList();
      if (typed.isEmpty) continue;
      final total = _sumByType(typed, type);
      sections.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${_typeSectionLabel(type)} (${typed.length})',
                    style: pw.TextStyle(font: boldFont, fontSize: 9.5, color: _typeColor(type, accent)),
                  ),
                  pw.Text(
                    '${total.toStringAsFixed(2)} $currency',
                    style: pw.TextStyle(font: boldFont, fontSize: 9, color: _typeColor(type, accent)),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              _transactionTable(
                transactions: typed,
                currency: currency,
                accounts: accounts,
                categories: categories,
                investments: investments,
                font: font,
                boldFont: boldFont,
                accent: _typeColor(type, accent),
              ),
            ],
          ),
        ),
      );
    }
    return pw.Column(children: sections);
  }

  static pw.Widget _sectionTitle(String text, PdfColor accent, pw.Font boldFont) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: pw.BoxDecoration(
            color: accent,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 6),
        pw.Text(
          text,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 11,
            color: const PdfColor.fromInt(0xFF111827),
          ),
        ),
      ],
    );
  }

  static pw.Widget _progressBar(double ratio, PdfColor color) {
    final safeRatio = ratio.clamp(0.0, 1.0);
    return pw.Row(
      children: [
        pw.Expanded(
          flex: (safeRatio * 1000).round().clamp(1, 1000).toInt(),
          child: pw.Container(height: 6, color: color),
        ),
        pw.Expanded(
          flex: ((1 - safeRatio) * 1000).round().clamp(1, 1000).toInt(),
          child: pw.Container(height: 6, color: const PdfColor.fromInt(0xFFE5E7EB)),
        ),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(font: boldFont, fontSize: 7.5, color: PdfColors.white),
      ),
    );
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    PdfColor color = const PdfColor.fromInt(0xFF111827),
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(font: font, fontSize: 7.2, color: color),
      ),
    );
  }

  static pw.Widget _footer(pw.Context context, pw.Font font) {
    return pw.Column(
      children: [
        pw.Divider(color: const PdfColor.fromInt(0xFFE5E7EB), thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Genere par MySold - ${_generatedAtFormat.format(DateTime.now())}',
              style: pw.TextStyle(font: font, fontSize: 7, color: const PdfColor.fromInt(0xFF64748B)),
            ),
            pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 7, color: const PdfColor.fromInt(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  static String _buildCsv({
    required List<TransactionModel> transactions,
    required String currency,
    required Map<String, String> accounts,
    required Map<String, Map<String, dynamic>> categories,
    required Map<String, String> investments,
  }) {
    final lines = <String>[
      [
        'Date',
        'Type',
        'Description',
        'Compte',
        'Categorie / Actif',
        'Montant',
        'Devise',
      ].map(_csvCell).join(';'),
      ...transactions.map((tx) {
        return [
          _dateFormat.format(tx.date),
          tx.type,
          tx.description,
          _accountLabel(tx, accounts),
          _referenceLabel(tx, categories, investments),
          tx.amount.toStringAsFixed(2),
          currency,
        ].map(_csvCell).join(';');
      }),
    ];

    return lines.join('\n');
  }

  static double _sumByType(List<TransactionModel> transactions, String type) {
    return transactions
        .where((tx) => tx.type == type)
        .fold(0.0, (sum, tx) => sum + tx.amount.abs());
  }

  static Map<String, double> _expenseCategoryTotals(
    List<TransactionModel> transactions,
    Map<String, Map<String, dynamic>> categories,
  ) {
    final totals = <String, double>{};
    for (final tx in transactions.where((tx) => tx.type == 'expense')) {
      final category = categories[tx.categoryId]?['name']?.toString() ?? 'Autre';
      totals[category] = (totals[category] ?? 0) + tx.amount.abs();
    }
    return totals;
  }

  static String _accountLabel(
    TransactionModel tx,
    Map<String, String> accounts,
  ) {
    final from = accounts[tx.fromAccountId] ?? 'Compte inconnu';
    final to = accounts[tx.toAccountId] ?? '';
    if (tx.type == 'transfer' || tx.type == 'investment') {
      return to.isEmpty ? from : '$from -> $to';
    }
    return from;
  }

  static String _referenceLabel(
    TransactionModel tx,
    Map<String, Map<String, dynamic>> categories,
    Map<String, String> investments,
  ) {
    if (tx.type == 'investment') {
      return investments[tx.investmentId] ?? 'Investissement';
    }
    return categories[tx.categoryId]?['name']?.toString() ?? '';
  }

  static String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Revenu';
      case 'expense':
        return 'Dépense';
      case 'investment':
        return 'Invest.';
      case 'transfer':
        return 'Transfert';
      default:
        return type;
    }
  }

  static String _typeSectionLabel(String type) {
    switch (type) {
      case 'income':
        return 'Revenus';
      case 'expense':
        return 'Dépenses';
      case 'investment':
        return 'Investissements';
      case 'transfer':
        return 'Transferts';
      default:
        return type;
    }
  }

  static PdfColor _typeColor(String type, PdfColor accent) {
    switch (type) {
      case 'income':
        return const PdfColor.fromInt(0xFF16A34A);
      case 'expense':
        return const PdfColor.fromInt(0xFFDC2626);
      case 'investment':
        return accent;
      case 'transfer':
        return const PdfColor.fromInt(0xFF64748B);
      default:
        return accent;
    }
  }

  static PdfColor _reportColor(String label, double value, PdfColor accent) {
    switch (label) {
      case 'Revenus':
        return const PdfColor.fromInt(0xFF16A34A);
      case 'Dépenses':
        return const PdfColor.fromInt(0xFFDC2626);
      case 'Investissements':
        return accent;
      case 'Transferts':
        return const PdfColor.fromInt(0xFF64748B);
      case 'Reste disponible':
        return value >= 0
            ? const PdfColor.fromInt(0xFF334155)
            : const PdfColor.fromInt(0xFFDC2626);
      default:
        return accent;
    }
  }

  static String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static Future<pw.Font> _loadPdfFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  static Future<pw.ImageProvider?> _loadImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      return null;
    }
  }

  static PdfColor _readableAccent(int value) {
    final rgb = value & 0x00FFFFFF;
    final red = (rgb >> 16) & 0xFF;
    final green = (rgb >> 8) & 0xFF;
    final blue = rgb & 0xFF;
    final luminance = (0.299 * red + 0.587 * green + 0.114 * blue) / 255;

    if (luminance > 0.82) {
      return const PdfColor.fromInt(0xFF334155);
    }
    if (luminance < 0.18) {
      return const PdfColor.fromInt(0xFF2563EB);
    }
    return PdfColor.fromInt(0xFF000000 | rgb);
  }

  static String _safeName(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

Future<Uint8List> _buildPdfBytesIsolate(Map<String, dynamic> payload) {
  final transactions = (payload['transactions'] as List)
      .cast<Map<dynamic, dynamic>>()
      .map(TransactionExportService._transactionFromPayload)
      .toList();
  final accounts = Map<String, String>.from(payload['accounts'] as Map);
  final categories = (payload['categories'] as Map).map(
    (key, value) => MapEntry(
      key.toString(),
      Map<String, dynamic>.from(value as Map),
    ),
  );
  final investments = Map<String, String>.from(payload['investments'] as Map);
  final regularFontBytes = payload['regularFont'] as Uint8List;
  final boldFontBytes = payload['boldFont'] as Uint8List;
  final logoBytes = payload['logo'] as Uint8List?;

  return TransactionExportService._buildPdfBytes(
    transactions: transactions,
    title: payload['title'] as String,
    currency: payload['currency'] as String,
    accounts: accounts,
    categories: categories,
    investments: investments,
    font: pw.Font.ttf(ByteData.sublistView(regularFontBytes)),
    boldFont: pw.Font.ttf(ByteData.sublistView(boldFontBytes)),
    logo: logoBytes == null ? null : pw.MemoryImage(logoBytes),
    accent: TransactionExportService._readableAccent(
      payload['primaryColor'] as int,
    ),
  );
}
