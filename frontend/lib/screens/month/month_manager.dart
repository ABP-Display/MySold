import 'package:mysold/widgets/page_activity_listener.dart';
import 'package:mysold/widgets/cached_page_stack.dart';
import 'package:mysold/widgets/month_page_header.dart';
import 'package:mysold/widgets/month_year_picker.dart';
import 'package:mysold/widgets/app_choice_tabs.dart';
import 'package:mysold/widgets/app_select_field.dart';
import 'package:mysold/widgets/app_design.dart';
// month_manager.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mysold/data/local_auth.dart';
import 'package:provider/provider.dart';

import 'package:mysold/l10n/app_localizations.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/providers/user_data_provider.dart';
import 'package:mysold/screens/month/month_dialog.dart';
import 'package:mysold/screens/month/month_graph.dart';
import 'package:mysold/widgets/transactions/tile/transaction_tile.dart';
import 'package:mysold/widgets/transactions/tile/transfer_tile.dart';
import 'package:mysold/widgets/transactions/tile/investment_tile.dart';
import 'package:mysold/services/budget_service.dart';
import 'package:mysold/screens/settings/currency_provider.dart';
import 'package:mysold/screens/settings/privacy_provider.dart';
import 'package:mysold/services/budget_alert_service.dart';
import 'package:mysold/services/local_notification_service.dart';

class MonthManagerScreen extends StatefulWidget {
  const MonthManagerScreen({super.key});

  @override
  State<MonthManagerScreen> createState() => _MonthManagerState();
}

class _MonthManagerState extends State<MonthManagerScreen> {
  DateTime _currentMonth = DateTime.now();
  List<TransactionModel> _transactions = [];
  bool _isLoadingTransactions = true;
  Object? _transactionsError;
  final user = LocalAuth.instance.currentUser;
  BudgetService? _firestoreService;
  final Map<String, Future<List<TransactionModel>>> _monthCache = {};
  Future<void>? _recentMonthsPreloadFuture;
  Map<String, Map<String, dynamic>> _categories = {};
  Map<String, String> _accountIds = {};
  Map<String, String> _investmentIds = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _selectedAccountId;
  double? _minAmount;
  double? _maxAmount;
  String _sortField = 'date';
  bool _sortAscending = false;
  int _selectedIndex = 0;
  int? _lastReferenceDataVersion;
  int? _lastFinancialDataVersion;
  bool _reloadScheduled = false;
  int _transactionLoad = 0;

  @override
  void initState() {
    super.initState();
    final currentUser = user;
    if (currentUser == null) {
      _isLoadingTransactions = false;
      return;
    }
    _firestoreService = BudgetService(userId: currentUser.uid);
    _loadTransactionsForSelectedMonth(showLoader: true);
  }

  Future<void> _refresh({bool forceRefresh = false}) async {
    await _loadTransactionsForSelectedMonth(
      forceRefresh: forceRefresh,
      showLoader: !forceRefresh,
    );
  }

  Future<void> _loadTransactionsForSelectedMonth({
    bool forceRefresh = false,
    bool showLoader = false,
  }) async {
    final service = _firestoreService;
    if (service == null) return;
    final month = _monthStart(_currentMonth);
    final request = ++_transactionLoad;

    if (showLoader && mounted) {
      setState(() {
        _isLoadingTransactions = true;
        _transactionsError = null;
      });
    }

    try {
      final transactions = forceRefresh
          ? await _loadFreshTransactionsForMonth(service, month)
          : await _getTransactionsForMonth(month);

      if (!mounted || request != _transactionLoad) return;
      setState(() {
        _transactions = transactions;
        _isLoadingTransactions = false;
        _transactionsError = null;
      });

      if (forceRefresh) {
        await _checkBudgetAlerts();
      }
    } catch (e) {
      if (!mounted || request != _transactionLoad) return;
      setState(() {
        _isLoadingTransactions = false;
        _transactionsError = e;
      });
    }
  }

  Future<List<TransactionModel>> _loadFreshTransactionsForMonth(
    BudgetService service,
    DateTime month,
  ) async {
    final key = _monthKey(month);
    final freshFuture = service.getTransactionsForMonth(month);
    _monthCache[key] = freshFuture;
    return freshFuture;
  }

  Future<void> _checkBudgetAlerts() async {
    final currentUser = user;
    if (currentUser == null) return;

    final triggered = await BudgetAlertService(
      userId: currentUser.uid,
    ).checkCurrentMonthAlerts();

    if (!mounted || triggered.isEmpty) return;

    for (final alert in triggered) {
      await LocalNotificationService.showBudgetAlert(alert);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${triggered.length} alerte budgetaire declenchee${triggered.length > 1 ? 's' : ''}',
        ),
      ),
    );
  }

  Future<List<TransactionModel>> _getTransactionsForMonth(DateTime month) {
    final service = _firestoreService;
    if (service == null) return Future.value([]);

    final normalizedMonth = _monthStart(month);
    final key = _monthKey(normalizedMonth);

    if (_isInRecentWindow(normalizedMonth)) {
      _recentMonthsPreloadFuture ??= _preloadRecentMonths();
      return _recentMonthsPreloadFuture!.then((_) {
        return _monthCache.putIfAbsent(
          key,
          () => service.getTransactionsForMonth(normalizedMonth),
        );
      });
    }

    return _monthCache.putIfAbsent(
      key,
      () => service.getTransactionsForMonth(normalizedMonth),
    );
  }

  Future<void> _preloadRecentMonths() async {
    final service = _firestoreService;
    if (service == null) return;

    final currentMonth = _monthStart(DateTime.now());
    final oldestMonth = DateTime(currentMonth.year, currentMonth.month - 11, 1);
    final rangeEnd = DateTime(currentMonth.year, currentMonth.month + 1, 1);

    final grouped = <String, List<TransactionModel>>{};
    for (var i = 0; i < 12; i++) {
      final month = DateTime(oldestMonth.year, oldestMonth.month + i, 1);
      grouped[_monthKey(month)] = [];
    }

    final transactions = await service.getTransactionsBetween(
      start: oldestMonth,
      end: rangeEnd,
      descending: true,
    );

    for (final transaction in transactions) {
      final key = _monthKey(transaction.date);
      grouped[key]?.add(transaction);
    }

    for (final entry in grouped.entries) {
      _monthCache.putIfAbsent(entry.key, () => Future.value(entry.value));
    }
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month, 1);

  String _monthKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month';
  }

  bool _isInRecentWindow(DateTime month) {
    final currentMonth = _monthStart(DateTime.now());
    final oldestMonth = DateTime(currentMonth.year, currentMonth.month - 11, 1);
    return !month.isBefore(oldestMonth) && !month.isAfter(currentMonth);
  }

  Future<void> _loadReferenceData({bool forceRefresh = false}) async {
    final references = context.read<UserDataProvider>();
    await references.ensureReferences(forceRefresh: forceRefresh);
    // Reference updates notify UserDataProvider, which this page already
    // watches. A cached resume needs no second setState/rebuild of its charts.
  }

  //
  // Navigation between months
  void _prevMonth() {
    _selectMonth(DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
  }

  void _nextMonth() {
    _selectMonth(DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
  }

  void _selectMonth(DateTime month) {
    final normalizedMonth = _monthStart(month);
    if (normalizedMonth == _monthStart(_currentMonth)) return;
    setState(() {
      _currentMonth = normalizedMonth;
    });
    _loadTransactionsForSelectedMonth(showLoader: true);
  }

  Future<void> _chooseMonth() async {
    final selected = await showMonthYearPicker(context, _currentMonth);
    if (mounted && selected != null) _selectMonth(selected);
  }

  String get _currentType =>
      const ['expense', 'income', 'investment', 'transfer'][_selectedIndex];

  String _typeLabel(String type) {
    switch (type) {
      case 'expense':
        return context.tr('Depenses');
      case 'income':
        return context.tr('Revenus');
      case 'investment':
        return context.tr('Investissements');
      case 'transfer':
        return context.tr('Transferts');
      default:
        return context.tr('Transactions');
    }
  }

  String _t(String key) => context.tr(key);

  String _monthlyTransactionsAmount(List<TransactionModel> txs, String type) {
    if (type == 'transfer') return '';

    final currency = context.watch<CurrencyProvider>().currency;
    final privacy = context.watch<PrivacyProvider>();
    final total = txs.fold<double>(
      0,
      (sum, transaction) => sum + transaction.amount.abs(),
    );

    if (type == 'expense') {
      return privacy.money(-total, currency);
    }
    if (type == 'income') {
      final formatted = privacy.money(total, currency);
      return privacy.hideAmounts ? formatted : '+$formatted';
    }
    return privacy.money(total, currency);
  }

  Color _monthlyAmountColor(String type) {
    final scheme = Theme.of(context).colorScheme;
    switch (type) {
      case 'expense':
        return scheme.error;
      case 'income':
        return Colors.green.shade600;
      case 'investment':
        return scheme.primary;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  bool get _hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _selectedAccountId != null ||
      _minAmount != null ||
      _maxAmount != null ||
      _sortField != 'date' ||
      _sortAscending;

  List<TransactionModel> _filteredTransactions(
    List<TransactionModel> txs,
    String type,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = txs.where((t) {
      if (t.type != type) return false;
      if (_selectedCategoryId != null && t.categoryId != _selectedCategoryId) {
        return false;
      }
      if (_selectedAccountId != null &&
          t.fromAccountId != _selectedAccountId &&
          t.toAccountId != _selectedAccountId) {
        return false;
      }
      final amount = t.amount.abs();
      if (_minAmount != null && amount < _minAmount!) return false;
      if (_maxAmount != null && amount > _maxAmount!) return false;
      if (query.isEmpty) return true;

      final searchable = [
        t.description,
        t.type,
        DateFormat('dd/MM/yyyy').format(t.date),
        t.amount.toStringAsFixed(2),
        _accountIds[t.fromAccountId] ?? '',
        _accountIds[t.toAccountId] ?? '',
        _categories[t.categoryId]?['name']?.toString() ?? '',
        _investmentIds[t.investmentId] ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      final cmp = _sortField == 'amount'
          ? a.amount.abs().compareTo(b.amount.abs())
          : a.date.compareTo(b.date);
      return _sortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategoryId = null;
      _selectedAccountId = null;
      _minAmount = null;
      _maxAmount = null;
      _sortField = 'date';
      _sortAscending = false;
    });
  }

  void _openFilterSheet() {
    String? tempAccountId = _selectedAccountId;
    String? tempCategoryId = _selectedCategoryId;
    String tempSortField = _sortField;
    bool tempSortAscending = _sortAscending;
    final minController = TextEditingController(
      text: _minAmount?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: _maxAmount?.toStringAsFixed(0) ?? '',
    );
    final currentType = _currentType;
    final categoryEntries =
        _categories.entries
            .where((entry) => entry.value['type'] == currentType)
            .toList()
          ..sort(
            (a, b) => (a.value['name'] ?? '').toString().compareTo(
              (b.value['name'] ?? '').toString(),
            ),
          );

    showAppSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Filtres',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    AppSelectField<String?>(
                      value: tempAccountId,
                      label: _t('Compte'),
                      icon: Icons.account_balance_wallet_outlined,
                      options: [
                        AppSelectOption<String?>(
                          value: null,
                          label: _t('Tous les comptes'),
                        ),
                        ..._accountIds.entries.map(
                          (entry) => AppSelectOption<String?>(
                            value: entry.key,
                            label: entry.value,
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setModalState(() => tempAccountId = value),
                    ),
                    if (currentType == 'expense' || currentType == 'income')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: AppSelectField<String?>(
                          value: tempCategoryId,
                          label: _t('Categorie'),
                          icon: Icons.category_outlined,
                          options: [
                            AppSelectOption<String?>(
                              value: null,
                              label: _t('Toutes les categories'),
                            ),
                            ...categoryEntries.map(
                              (entry) => AppSelectOption<String?>(
                                value: entry.key,
                                label:
                                    entry.value['name']?.toString() ??
                                    'Sans nom',
                                color: entry.value['color'] is int
                                    ? Color(entry.value['color'])
                                    : null,
                              ),
                            ),
                          ],
                          onChanged: (value) =>
                              setModalState(() => tempCategoryId = value),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: minController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: _t('Montant min'),
                              prefixIcon: const Icon(
                                Icons.arrow_downward_rounded,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: maxController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: _t('Montant max'),
                              prefixIcon: const Icon(
                                Icons.arrow_upward_rounded,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _t('Tri'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tempSortField,
                      decoration: InputDecoration(
                        labelText: _t('Trier par'),
                        prefixIcon: const Icon(Icons.sort_rounded),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'date',
                          child: Text(_t('Date')),
                        ),
                        DropdownMenuItem(
                          value: 'amount',
                          child: Text(_t('Montant')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModalState(() => tempSortField = value);
                      },
                    ),
                    Material(
                      color: Colors.transparent,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          tempSortAscending
                              ? _t('Ordre croissant')
                              : _t('Ordre decroissant'),
                        ),
                        value: tempSortAscending,
                        onChanged: (value) =>
                            setModalState(() => tempSortAscending = value),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _resetFilters();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(_t('Reinitialiser')),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () {
                            final min = double.tryParse(
                              minController.text.replaceAll(',', '.'),
                            );
                            final max = double.tryParse(
                              maxController.text.replaceAll(',', '.'),
                            );
                            if (min != null && max != null && min > max) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Le montant min doit etre inferieur au max.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _selectedAccountId = tempAccountId;
                              _selectedCategoryId =
                                  currentType == 'expense' ||
                                      currentType == 'income'
                                  ? tempCategoryId
                                  : null;
                              _minAmount = min;
                              _maxAmount = max;
                              _sortField = tempSortField;
                              _sortAscending = tempSortAscending;
                            });
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.check_rounded),
                          label: Text(_t('Appliquer')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActiveFilterChips() {
    if (!_hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];
    if (_searchQuery.trim().isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('${_t('Recherche')}: $_searchQuery'),
          onDeleted: () {
            setState(() {
              _searchController.clear();
              _searchQuery = '';
            });
          },
        ),
      );
    }
    if (_selectedAccountId != null) {
      chips.add(
        InputChip(
          label: Text(_accountIds[_selectedAccountId] ?? 'Compte'),
          avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
          onDeleted: () => setState(() => _selectedAccountId = null),
        ),
      );
    }
    if (_selectedCategoryId != null) {
      chips.add(
        InputChip(
          label: Text(
            _categories[_selectedCategoryId]?['name']?.toString() ??
                'Categorie',
          ),
          avatar: const Icon(Icons.category_outlined, size: 18),
          onDeleted: () => setState(() => _selectedCategoryId = null),
        ),
      );
    }
    if (_minAmount != null || _maxAmount != null) {
      chips.add(
        InputChip(
          label: Text(
            '${_minAmount?.toStringAsFixed(0) ?? '0'} - ${_maxAmount?.toStringAsFixed(0) ?? 'max'}',
          ),
          avatar: const Icon(Icons.euro_symbol_rounded, size: 18),
          onDeleted: () => setState(() {
            _minAmount = null;
            _maxAmount = null;
          }),
        ),
      );
    }
    if (_sortField != 'date' || _sortAscending) {
      chips.add(
        InputChip(
          label: Text(
            'Tri: ${_sortField == 'amount' ? 'montant' : 'date'} ${_sortAscending ? 'croissant' : 'decroissant'}',
          ),
          avatar: const Icon(Icons.sort_rounded, size: 18),
          onDeleted: () => setState(() {
            _sortField = 'date';
            _sortAscending = false;
          }),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemBuilder: (_, index) => chips[index],
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: chips.length,
      ),
    );
  }

  Widget _buildTabContent(
    List<TransactionModel> txs,
    String type,
    String monthLabel,
  ) {
    final filtered = _filteredTransactions(txs, type);
    final monthlyAmount = _monthlyTransactionsAmount(filtered, type);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: MonthPageHeader(
                  eyebrow: _t('VOTRE BUDGET'),
                  title: _t('Budget mensuel'),
                  subtitle: _t('Vos opérations, simplement.'),
                  monthLabel: monthLabel,
                  compactMonthLabel: DateFormat(
                    'MMM yyyy',
                    Localizations.localeOf(context).toString(),
                  ).format(_currentMonth),
                  previousLabel: _t('Mois précédent'),
                  nextLabel: _t('Mois suivant'),
                  onPrevious: _prevMonth,
                  onNext: _nextMonth,
                  onChoose: _chooseMonth,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: AppChoiceTabs(
                  labels: [
                    'expense',
                    'income',
                    'investment',
                    'transfer',
                  ].map(_typeLabel).toList(),
                  icons: const [
                    Icons.money_off_outlined,
                    Icons.attach_money,
                    Icons.trending_up_outlined,
                    Icons.sync_alt,
                  ],
                  selectedIndex: _selectedIndex,
                  onSelected: (index) {
                    if (index == _selectedIndex) return;
                    setState(() {
                      _selectedIndex = index;
                      _selectedCategoryId = null;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppPanel(
                  padding: EdgeInsets.zero,
                  child: ExpansionTile(
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(
                      _t('Répartition du mois'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    leading: const Icon(Icons.bar_chart_outlined, size: 20),
                    initiallyExpanded: MediaQuery.sizeOf(context).width >= 760,
                    children: [
                      MonthGraph(
                        transactions: filtered,
                        categories: _categories,
                        accountIds: _accountIds,
                        investmentIds: _investmentIds,
                        type: type,
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: _t('Rechercher une transaction'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: _t('Effacer'),
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              _buildActiveFilterChips(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${_t('Transactions mensuelles')} (${filtered.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (monthlyAmount.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Text(
                        monthlyAmount,
                        style: TextStyle(
                          color: _monthlyAmountColor(type),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        // Bouton filtre catégorie
                        IconButton(
                          icon: Icon(
                            _hasActiveFilters
                                ? Icons.tune_rounded
                                : Icons.tune_outlined,
                            size: 20,
                          ),
                          tooltip: _t('Filtrer et trier'),
                          onPressed: _openFilterSheet,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _hasActiveFilters
                      ? _t('Aucune transaction ne correspond aux filtres.')
                      : _t('Aucune transaction sur cette periode.'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 88),
            sliver: SliverList.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final t = filtered[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: () {
                    if (t.type == 'transfer') {
                      return TransferTransactionTile(
                        t: t,
                        accounts: _accountIds,
                        investments: _investmentIds,
                        onChanged: () {
                          _refresh(forceRefresh: true);
                        },
                      );
                    } else if (t.type == 'investment') {
                      return InvestmentTransactionTile(
                        t: t,
                        accounts: _accountIds,
                        investments: _investmentIds,
                        onChanged: () {
                          _refresh(forceRefresh: true);
                        },
                      );
                    } else {
                      return TransactionTile(
                        t: t,
                        categories: _categories,
                        accounts: _accountIds,
                        onChanged: () {
                          _refresh(forceRefresh: true);
                        },
                      );
                    }
                  }(),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final references = context.watch<UserDataProvider>();
    final financialVersion = references.financialDataVersion;
    if (_lastFinancialDataVersion != null &&
        _lastFinancialDataVersion != financialVersion &&
        !_reloadScheduled) {
      _reloadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reloadScheduled = false;
        if (!mounted) return;
        _monthCache.clear();
        _recentMonthsPreloadFuture = null;
        _loadTransactionsForSelectedMonth(forceRefresh: true);
      });
    }
    _lastFinancialDataVersion = financialVersion;

    if (_lastReferenceDataVersion != references.referenceDataVersion) {
      _lastReferenceDataVersion = references.referenceDataVersion;
      _categories = references.categories;
      _accountIds = references.accounts;
      _investmentIds = references.investments;
    }

    final monthLabel = DateFormat(
      'MMMM yyyy',
      Localizations.localeOf(context).toString(),
    ).format(_currentMonth);

    return PageActivityListener(
      onResume: _loadReferenceData,
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: _MonthAddFab(
          onRefresh: () => _refresh(forceRefresh: true),
        ),
        body: _transactionsError != null
            ? Center(child: Text('${_t('Erreur')} : $_transactionsError'))
            : _isLoadingTransactions && _transactions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CachedPageStack(
                index: _selectedIndex,
                itemCount: 4,
                revision: (
                  transactions: _transactions,
                  month: (_currentMonth.year, _currentMonth.month),
                  references: references.referenceDataVersion,
                  filters: (
                    _searchQuery,
                    _selectedCategoryId,
                    _selectedAccountId,
                    _minAmount,
                    _maxAmount,
                    _sortField,
                    _sortAscending,
                  ),
                  currency: context.watch<CurrencyProvider>().currency,
                  hidden: context.watch<PrivacyProvider>().hideAmounts,
                  theme: Theme.of(context),
                  locale: Localizations.localeOf(context),
                ),
                itemBuilder: (_, index) => _buildTabContent(
                  _transactions,
                  ['expense', 'income', 'investment', 'transfer'][index],
                  monthLabel,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _MonthAddFab extends StatefulWidget {
  final Future<void> Function() onRefresh;

  const _MonthAddFab({required this.onRefresh});

  @override
  State<_MonthAddFab> createState() => _MonthAddFabState();
}

class _MonthAddFabState extends State<_MonthAddFab> {
  bool _isOpen = false;

  Future<void> _openDialog(String type) async {
    setState(() => _isOpen = false);
    await openAddDialog(context, type, widget.onRefresh);
  }

  Widget _buildMiniFab(IconData icon, String tooltip, String type, int index) {
    final duration = Duration(milliseconds: 180 + (index * 55));
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      height: _isOpen ? 48 : 0,
      padding: EdgeInsets.only(bottom: _isOpen ? 8 : 0),
      child: AnimatedOpacity(
        duration: duration,
        opacity: _isOpen ? 1 : 0,
        curve: Curves.easeOut,
        child: AnimatedSlide(
          duration: duration,
          curve: Curves.easeOutBack,
          offset: _isOpen ? Offset.zero : const Offset(0, 0.35),
          child: IgnorePointer(
            ignoring: !_isOpen,
            child: FloatingActionButton.small(
              heroTag: tooltip,
              tooltip: tooltip,
              onPressed: () => _openDialog(type),
              child: Icon(icon),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildMiniFab(Icons.attach_money, 'Transaction', 'transaction', 0),
          _buildMiniFab(Icons.trending_up, 'Investissement', 'investment', 1),
          _buildMiniFab(Icons.swap_horiz, 'Transfert', 'transfer', 2),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: _isOpen ? 8 : 0,
          ),
          FloatingActionButton(
            onPressed: () => setState(() => _isOpen = !_isOpen),
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
