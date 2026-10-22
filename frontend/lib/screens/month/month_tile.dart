// month_tile.dart
import 'package:flutter/material.dart';

import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/widgets/transactions/tile/transaction_tile.dart';

class MonthTile extends StatefulWidget {
  final List<TransactionModel> transactions;
  final Map<String, String> categoryNames;
  final String type;
  final VoidCallback onRefresh;
  final VoidCallback onFilter;
  final VoidCallback onSort;

  const MonthTile({
    super.key,
    required this.transactions,
    required this.categoryNames,
    required this.type,
    required this.onRefresh,
    required this.onFilter,
    required this.onSort,
  });

  @override
  State<MonthTile> createState() => _MonthTile();
}

class _MonthTile extends State<MonthTile> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("Type : ${widget.type}"),
        ElevatedButton(
          onPressed: widget.onFilter,
          child: const Text("Filtrer"),
        ),
        ElevatedButton(onPressed: widget.onSort, child: const Text("Trier")),
        Expanded(
          child: ListView.builder(
            itemCount: widget.transactions.length,
            itemBuilder: (context, index) {
              final tx = widget.transactions[index];
              return TransactionTile(
                t: tx,
                onChanged: widget.onRefresh, // ou autre callback si différent
              );
            },
          ),
        ),
      ],
    );
  }
}
