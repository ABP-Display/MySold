import 'package:mysold/data/document_store.dart';

class BudgetAlertService {
  final String userId;
  final DocumentStore _firestore = DocumentStore.instance;

  BudgetAlertService({required this.userId});

  CollectionReference<Map<String, dynamic>> get _transactions {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('transactions');
  }

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _firestore.collection('users').doc(userId).collection('budgetAlerts');

  Future<List<BudgetAlert>> getAlerts() async {
    final snapshot = await _alerts.get();
    return snapshot.docs
        .map((doc) => BudgetAlert.fromJson({...doc.data(), 'id': doc.id}))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> saveAlert({
    String? alertId,
    required String title,
    required double thresholdPercent,
    required bool isEnabled,
  }) async {
    final alerts = await getAlerts();
    final now = DateTime.now();
    final index = alerts.indexWhere((alert) => alert.id == alertId);

    final alert = BudgetAlert(
      id: alertId ?? now.microsecondsSinceEpoch.toString(),
      title: title,
      thresholdPercent: thresholdPercent,
      isEnabled: isEnabled,
      createdAt: index >= 0 ? alerts[index].createdAt : now,
      lastTriggeredPeriod: index >= 0
          ? alerts[index].lastTriggeredPeriod
          : null,
    );

    if (index >= 0) {
      alerts[index] = alert;
    } else {
      alerts.add(alert);
    }

    await _saveAlerts(alerts);
  }

  Future<void> deleteAlert(String alertId) async {
    final alerts = await getAlerts();
    alerts.removeWhere((alert) => alert.id == alertId);
    await _saveAlerts(alerts);
  }

  Future<BudgetMonthStats> getCurrentMonthStats() {
    return getMonthStats(DateTime.now());
  }

  Future<BudgetMonthStats> getMonthStats(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    final snapshot = await _transactions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    var income = 0.0;
    var expense = 0.0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0).toDouble();
      final type = data['type'];

      if (type == 'income') {
        income += amount;
      } else if (type == 'expense') {
        expense += amount;
      }
    }

    return BudgetMonthStats(
      income: income,
      expense: expense,
      monthKey: _monthKey(start),
    );
  }

  Future<List<BudgetAlertResult>> checkCurrentMonthAlerts() async {
    final stats = await getCurrentMonthStats();
    final alerts = await getAlerts();
    final triggered = <BudgetAlertResult>[];

    for (var i = 0; i < alerts.length; i++) {
      final alert = alerts[i];
      if (!alert.isEnabled) continue;

      if (stats.expenseIncomePercent >= alert.thresholdPercent &&
          alert.lastTriggeredPeriod != stats.monthKey) {
        triggered.add(
          BudgetAlertResult(
            alertId: alert.id,
            title: alert.title,
            thresholdPercent: alert.thresholdPercent,
            currentPercent: stats.expenseIncomePercent,
          ),
        );

        alerts[i] = alert.copyWith(lastTriggeredPeriod: stats.monthKey);
      }
    }

    if (triggered.isNotEmpty) {
      await _saveAlerts(alerts);
    }

    return triggered;
  }

  Future<void> _saveAlerts(List<BudgetAlert> alerts) async {
    final previous = await _alerts.get();
    final batch = _firestore.batch();
    final ids = alerts.map((alert) => alert.id).toSet();
    for (final doc in previous.docs) {
      if (!ids.contains(doc.id)) batch.delete(doc.reference);
    }
    for (final alert in alerts) {
      batch.set(_alerts.doc(alert.id), alert.toJson());
    }
    if (previous.docs.isNotEmpty || alerts.isNotEmpty) await batch.commit();
  }

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }
}

class BudgetAlert {
  final String id;
  final String title;
  final double thresholdPercent;
  final bool isEnabled;
  final DateTime createdAt;
  final String? lastTriggeredPeriod;

  const BudgetAlert({
    required this.id,
    required this.title,
    required this.thresholdPercent,
    required this.isEnabled,
    required this.createdAt,
    this.lastTriggeredPeriod,
  });

  factory BudgetAlert.fromJson(Map<String, dynamic> json) {
    return BudgetAlert(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? 'Alerte budgetaire').toString(),
      thresholdPercent: (json['thresholdPercent'] ?? 0).toDouble(),
      isEnabled: json['isEnabled'] == false ? false : true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      lastTriggeredPeriod: json['lastTriggeredPeriod']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'thresholdPercent': thresholdPercent,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
      'lastTriggeredPeriod': lastTriggeredPeriod,
    };
  }

  BudgetAlert copyWith({String? lastTriggeredPeriod}) {
    return BudgetAlert(
      id: id,
      title: title,
      thresholdPercent: thresholdPercent,
      isEnabled: isEnabled,
      createdAt: createdAt,
      lastTriggeredPeriod: lastTriggeredPeriod ?? this.lastTriggeredPeriod,
    );
  }
}

class BudgetMonthStats {
  final double income;
  final double expense;
  final String monthKey;

  const BudgetMonthStats({
    required this.income,
    required this.expense,
    required this.monthKey,
  });

  double get expenseIncomePercent {
    if (income <= 0) return 0;
    return (expense / income) * 100;
  }
}

class BudgetAlertResult {
  final String alertId;
  final String title;
  final double thresholdPercent;
  final double currentPercent;

  const BudgetAlertResult({
    required this.alertId,
    required this.title,
    required this.thresholdPercent,
    required this.currentPercent,
  });
}
