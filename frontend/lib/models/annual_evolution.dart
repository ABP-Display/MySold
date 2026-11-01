double _money(double value) => double.parse(value.toStringAsFixed(2));

class EvolutionEntry {
  final String id, name;
  final double beginning, ending;
  const EvolutionEntry({
    required this.id,
    required this.name,
    required this.beginning,
    required this.ending,
  });
  double get change => _money(ending - beginning);
  // A zero baseline has no defined percentage. Absolute change remains useful.
  double? get percent => beginning == 0
      ? (ending == 0 ? 0 : null)
      : change / beginning.abs() * 100;
}

class AnnualEvolution {
  final int year;
  final DateTime endingDate;
  final bool isFuture;
  final String source;
  final List<EvolutionEntry> accounts, expenses, income;
  const AnnualEvolution({
    required this.year,
    required this.endingDate,
    required this.isFuture,
    required this.source,
    required this.accounts,
    required this.expenses,
    required this.income,
  });

  factory AnnualEvolution.fromMap(Map<String, dynamic> data) {
    EvolutionEntry entry(dynamic value) {
      final row = value as Map<String, dynamic>;
      return EvolutionEntry(
        id: row['id'] as String,
        name: row['name'] as String? ?? '',
        beginning: (row['beginning'] as num).toDouble(),
        ending: (row['ending'] as num).toDouble(),
      );
    }

    final categories = data['categories'] as List;
    return AnnualEvolution(
      year: data['year'] as int,
      endingDate: DateTime.parse(data['asOf'] as String),
      isFuture: data['future'] == true,
      source: data['source'] as String,
      accounts: (data['accounts'] as List).map(entry).toList(),
      expenses: categories
          .where((row) => row['type'] == 'expense')
          .map(entry)
          .toList(),
      income: categories
          .where((row) => row['type'] == 'income')
          .map(entry)
          .toList(),
    );
  }
  factory AnnualEvolution.empty(int year) => AnnualEvolution(
    year: year,
    endingDate: DateTime(year),
    isFuture: false,
    source: 'unavailable',
    accounts: const [],
    expenses: const [],
    income: const [],
  );
}
