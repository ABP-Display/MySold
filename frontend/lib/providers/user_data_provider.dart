import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:mysold/services/budget_service.dart';

class UserDataProvider extends ChangeNotifier {
  static const Duration _cacheDuration = Duration(minutes: 5);

  String? _userId;
  DateTime? _lastReferenceLoad;
  Future<void>? _referenceLoadFuture;

  Map<String, String> _accounts = {};
  Map<String, String> _manualAccounts = {};
  Map<String, String> _investments = {};
  Map<String, Map<String, dynamic>> _categories = {};
  int _financialDataVersion = 0;
  int _referenceDataVersion = 0;

  Map<String, String> get accounts => Map.unmodifiable(_accounts);
  Map<String, String> get manualAccounts => Map.unmodifiable(_manualAccounts);
  Map<String, String> get investments => Map.unmodifiable(_investments);
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
    _lastReferenceLoad = null;
    _referenceLoadFuture = null;
    _accounts = {};
    _manualAccounts = {};
    _investments = {};
    _categories = {};
    _notifySafely();
  }

  Future<void> ensureReferences({bool forceRefresh = false}) {
    final userId = _userId;
    if (userId == null) return Future.value();

    final loadedAt = _lastReferenceLoad;
    final isFresh = loadedAt != null &&
        DateTime.now().difference(loadedAt) < _cacheDuration &&
        hasReferences;

    if (!forceRefresh && isFresh) return Future.value();
    if (!forceRefresh && _referenceLoadFuture != null) {
      return _referenceLoadFuture!;
    }

    final service = BudgetService(userId: userId);
    _referenceLoadFuture = () async {
      final accountsFuture = service.getAccounts();
      final manualAccountsFuture = service.getManualAccounts();
      final investmentsFuture = service.getInvestments();
      final categoriesFuture = service.getCategoriesAsMap();

      final accounts = await accountsFuture;
      final manualAccounts = await manualAccountsFuture;
      final investments = await investmentsFuture;
      final categories = await categoriesFuture;

      _accounts = accounts;
      _manualAccounts = manualAccounts;
      _investments = investments;
      _categories = categories;
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

  void markFinancialDataChanged() {
    _financialDataVersion++;
    _notifySafely();
  }
}
