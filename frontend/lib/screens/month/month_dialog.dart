import 'package:flutter/material.dart';
import 'package:mysold/widgets/transactions/dialog/add_transaction_dialog.dart';
import 'package:mysold/widgets/transactions/dialog/add_transfer_dialog.dart';
import 'package:mysold/widgets/transactions/dialog/add_investment_dialog.dart';

Future<void> openAddDialog(
  BuildContext context,
  String type,
  Future<void> Function() onRefresh,
) async {
  Widget dialog;

  switch (type) {
    case 'transaction':
      dialog = const AddTransactionDialog();
      break;
    case 'investment':
      dialog = const AddInvestmentDialog();
      break;
    case 'transfer':
      dialog = const AddTransferDialog();
      break;
    default:
      return;
  }

  final result = await showDialog(context: context, builder: (_) => dialog);

  if (result == true) {
    await onRefresh();
  }
}
