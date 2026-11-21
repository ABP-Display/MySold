enum CategoryEvolutionState { comparable, newActivity, inactive, unavailable }

class CategoryEvolution {
  final CategoryEvolutionState state;
  final double? percent;
  const CategoryEvolution(this.state, [this.percent]);

  factory CategoryEvolution.fromSummary(Map<String, dynamic>? entity) {
    final current = entity?['current'], previous = entity?['previous'];
    if (current is! num ||
        previous is! num ||
        !current.isFinite ||
        !previous.isFinite ||
        previous < 0) {
      return const CategoryEvolution(CategoryEvolutionState.unavailable);
    }
    if (previous == 0) {
      return CategoryEvolution(
        current == 0
            ? CategoryEvolutionState.inactive
            : CategoryEvolutionState.newActivity,
      );
    }
    return CategoryEvolution(
      CategoryEvolutionState.comparable,
      (current - previous) / previous * 100,
    );
  }

  String? get label => switch (state) {
    CategoryEvolutionState.comparable => null,
    CategoryEvolutionState.newActivity => 'Nouveau',
    CategoryEvolutionState.inactive => 'Sans activité',
    CategoryEvolutionState.unavailable => 'Indisponible',
  };

  String get hint => switch (state) {
    CategoryEvolutionState.comparable => 'Année précédente, même période',
    CategoryEvolutionState.newActivity =>
      'Aucun montant sur la même période de l’année précédente.',
    CategoryEvolutionState.inactive =>
      'Aucun montant sur les deux périodes comparées.',
    CategoryEvolutionState.unavailable =>
      'Historique de comparaison indisponible.',
  };
}

List<double?> annualChartValues(
  Map<String, dynamic> entity,
  int year,
  DateTime asOf,
) {
  final cutoff = asOf.toUtc();
  final months = cutoff.year > year
      ? 12
      : cutoff.year < year
      ? 0
      : cutoff.month;
  final source =
      (entity['kind'] == 'categories' ? entity['monthly'] : entity['closing'])
          as List? ??
      const [];
  final category = entity['kind'] == 'categories';
  var totalCents = 0;
  var complete = true;
  return List.generate(12, (index) {
    if (index >= months) return null;
    if (index >= source.length || source[index] is! num) {
      if (category) complete = false;
      return null;
    }
    final value = (source[index] as num).toDouble();
    if (!value.isFinite) {
      if (category) complete = false;
      return null;
    }
    if (!category) return value;
    if (!complete) return null;
    totalCents += (value * 100).round();
    return totalCents / 100;
  });
}
