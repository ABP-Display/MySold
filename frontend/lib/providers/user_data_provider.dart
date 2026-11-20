import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mysold/data/bounded_async_cache.dart';
import 'package:mysold/data/document_store.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/models/investment_type.dart';

import 'package:mysold/services/budget_service.dart';

class UserDataProvider extends ChangeNotifier {
  static const Duration _cacheDuration = Duration(minutes: 5);

  String? _userId;
  DateTime? _lastReferenceLoad;
  Future<void>? _referenceLoadFuture;

  Map<String, String> _accounts = {};
  Map<String, String> _manualAccounts = {};
  Map<String, String> _investments = {};
  Map<String, String> _investmentTypes = {};
  List<InvestmentTypeOption> _investmentCategories = investmentTypeOptions;
  Map<String, Map<String, dynamic>> _categories = {};
  int _financialDataVersion = 0;
  int _referenceDataVersion = 0;
  final _monthTransactions =
      BoundedAsyncCache<
        ({String user, DateTime month}),
        List<TransactionModel>
      >(capacity: 6);
  int? _transactionGeneration;

  void _syncTransactionCache() {
    final generation = DocumentStore.instance.generation;
    if (_transactionGeneration != generation) {
      _monthTransactions.clear();
      _transactionGeneration = generation;
    }
  }

  List<TransactionModel>? cachedMonthTransactions(DateTime date) {
    _syncTransactionCache();
    final uid = _userId;
    if (uid == null) return null;
    return _monthTransactions.peek((
      user: uid,
      month: DateTime(date.year, date.month),
    ));
  }

  Future<List<TransactionModel>> getMonthTransactions(DateTime date) {
    final uid = _userId;
    if (uid == null) return Future.value(const []);
    _syncTransactionCache();
    final month = DateTime(date.year, date.month);
    return _monthTransactions.load((user: uid, month: month), () async {
      final transactions = await BudgetService(
        userId: uid,
      ).getTransactionsForMonth(month);
      return List.unmodifiable(transactions);
    });
  }

  Map<String, String> get accounts => Map.unmodifiable(_accounts);
  Map<String, String> get manualAccounts => Map.unmodifiable(_manualAccounts);
  Map<String, String> get investments => Map.unmodifiable(_investments);
  Map<String, String> get investmentTypes => Map.unmodifiable(_investmentTypes);
  List<InvestmentTypeOption> get investmentCategories => _investmentCategories;
  Map<String, Map<String, dynamic>> get categories =>
      Map.unmodifiable(_categories);
  int get financialDataVersion => _financialDataVersion;
  int get referenceDataVersion => _referenceDataVersion;

  bool get hasReferences =>
      _accounts.isNotEmpty || _investments.isNotEmpty || _categories.isNotEmpty;

  void _notifySafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void setUser(String? userId) {
    if (_userId == userId) return;

    _userId = userId;
    _monthTransactions.clear();
    _financialDataVersion++;
    _referenceDataVersion++;
    _lastReferenceLoad = null;
    _referenceLoadFuture = null;
    _accounts = {};
    _manualAccounts = {};
    _investments = {};
    _investmentTypes = {};
    _investmentCategories = investmentTypeOptions;
    _categories = {};
    _notifySafely();
  }

  Future<void> ensureReferences({bool forceRefresh = false}) {
    final userId = _userId;
    if (userId == null) return Future.value();

    final loadedAt = _lastReferenceLoad;
    final isFresh =
        loadedAt != null &&
        DateTime.now().difference(loadedAt) < _cacheDuration;

    if (!forceRefresh && isFresh) return Future.value();
    if (!forceRefresh && _referenceLoadFuture != null) {
      return _referenceLoadFuture!;
    }

    final service = BudgetService(userId: userId);
    _referenceLoadFuture =
        () async {
          final accountsFuture = service.getAccounts();
          final manualAccountsFuture = service.getManualAccounts();
          final investmentsFuture = service.getInvestmentCatalog();
          final categoriesFuture = service.getCategoriesAsMap();
          final profileFuture = DocumentStore.instance
              .doc('users/$userId')
              .get();

          final accounts = await accountsFuture;
          final manualAccounts = await manualAccountsFuture;
          final investments = await investmentsFuture;
          final categories = await categoriesFuture;
          final profile = await profileFuture;
          if (_userId != userId) return;

          _accounts = accounts;
          _manualAccounts = manualAccounts;
          _investments = {
            for (final entry in investments.entries)
              entry.key: entry.value['name']!,
          };
          _investmentTypes = {
            for (final entry in investments.entries)
              entry.key: entry.value['type']!,
          };
          _categories = categories;
          _investmentCategories = investmentCategoriesFromProfile(
            profile.data()?['investmentCategories'],
          );
          _lastReferenceLoad = DateTime.now();
          _referenceDataVersion++;
          _notifySafely();
        }().whenComplete(() {
          _referenceLoadFuture = null;
        });

    return _referenceLoadFuture!;
  }

  Future<Map<String, String>> getAccounts({bool forceRefresh = false}) async {
    await ensureReferences(forceRefresh: forceRefresh);
    return accounts;
  }

  Future<Map<String, String>> getManualAccounts({
    bool forceRefresh = false,
  }) async {
    await ensureReferences(forceRefresh: forceRefresh);
    return manualAccounts;
  }

  Future<Map<String, String>> getInvestments({
    bool forceRefresh = false,
  }) async {
    await ensureReferences(forceRefresh: forceRefresh);
    return investments;
  }

  Future<Map<String, Map<String, dynamic>>> getCategories({
    String? type,
    bool forceRefresh = false,
  }) async {
    await ensureReferences(forceRefresh: forceRefresh);
    if (type == null) return categories;

    return Map.unmodifiable({
      for (final entry in _categories.entries)
        if (entry.value['type'] == type) entry.key: entry.value,
    });
  }

  void invalidateReferences() {
    _lastReferenceLoad = null;
    _referenceDataVersion++;
    _notifySafely();
  }

  Future<void> saveInvestmentCategories(
    List<InvestmentTypeOption> options,
  ) async {
    final uid = _userId;
    if (uid == null) throw StateError('Utilisateur déconnecté');
    await DocumentStore.instance.doc('users/$uid').set({
      'investmentCategories': options.map((o) => o.toMap()).toList(),
    }, SetOptions(merge: true));
    if (_userId != uid) return;
    _investmentCategories = List.unmodifiable(options);
    _referenceDataVersion++;
    _notifySafely();
  }

  void markFinancialDataChanged() {
    _monthTransactions.clear();
    _financialDataVersion++;
    _notifySafely();
  }
}
