import 'package:mysold/data/document_store.dart';

class TransactionModel {
  String? id;
  double amount;
  DateTime date;
  String description;
  String type; // "income", "expense", "investment", "transfer"
  //String? accountId;
  String? categoryId;
  //Color? categoryColor;
  //IconData? categoryIcon;
  //String? categoryName;
  String? fromAccountId;
  String? toAccountId;
  String? investmentId;

  TransactionModel({
    this.id,
    required this.amount,
    required this.date,
    required this.description,
    required this.type,
    //this.accountId,
    this.categoryId,
    //this.categoryColor,
    //this.categoryIcon,
    //this.categoryName,
    this.fromAccountId,
    this.toAccountId,
    this.investmentId,
  });

  static double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Map<String, dynamic> toMap() {
    return {
      //'id': id,
      'amount': _roundMoney(amount),
      'date': Timestamp.fromDate(date),
      'description': description,
      'type': type,
      //'accountId': accountId,
      'categoryId': categoryId,
      //'categoryColor': categoryColor?.value,
      //'categoryIcon': categoryIcon?.codePoint,
      //'categoryName': categoryName,
      'fromAccountId': fromAccountId,
      'toAccountId': toAccountId,
      'investmentId': investmentId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      amount: _roundMoney((data['amount'] as num).toDouble()),
      date: (data['date'] as Timestamp).toDate(),
      description: data['description'] ?? '',
      type: data['type'] ?? '',
      //accountId: data['accountId'] is DocumentReference ? (data['accountId'] as DocumentReference).id : data['accountId'],
      categoryId: data['categoryId'] is DocumentReference
          ? (data['categoryId'] as DocumentReference).id
          : data['categoryId'],
      //categoryColor: data['categoryColor'] != null ? Color(data['categoryColor']) : null,
      //categoryIcon: data['categoryIcon'] != null ? IconData(data['categoryIcon'], fontFamily: 'MaterialIcons') : null,
      //categoryName: data['categoryName'],
      fromAccountId: data['fromAccountId'] is DocumentReference
          ? (data['fromAccountId'] as DocumentReference).id
          : data['fromAccountId'],
      toAccountId: data['toAccountId'] is DocumentReference
          ? (data['toAccountId'] as DocumentReference).id
          : data['toAccountId'],
      investmentId: data['investmentId'] is DocumentReference
          ? (data['investmentId'] as DocumentReference).id
          : data['investmentId'],
    );
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? description,
    String? type,
    //String? accountId,
    String? categoryId,
    //Color? categoryColor,
    //IconData? categoryIcon,
    //String? categoryName,
    String? fromAccountId,
    String? toAccountId,
    String? investmentId,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      type: type ?? this.type,
      //accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      //categoryColor: categoryColor ?? this.categoryColor,
      //categoryIcon: categoryIcon ?? this.categoryIcon,
      //categoryName: categoryName ?? this.categoryName,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      investmentId: investmentId ?? this.investmentId,
    );
  }
}
