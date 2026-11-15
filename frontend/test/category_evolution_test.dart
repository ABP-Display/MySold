import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/category_evolution.dart';

void main() {
  test('Category rates compare the same period without dividing by zero', () {
    final growth = CategoryEvolution.fromSummary({
      'current': 150,
      'previous': 100,
    });
    expect(growth.percent, 50);
    expect(growth.state, CategoryEvolutionState.comparable);
    expect(
      CategoryEvolution.fromSummary({'current': 0, 'previous': 100}).percent,
      -100,
    );
    expect(
      CategoryEvolution.fromSummary({'current': 125, 'previous': 0}).state,
      CategoryEvolutionState.newActivity,
    );
    expect(
      CategoryEvolution.fromSummary({'current': 0, 'previous': 0}).state,
      CategoryEvolutionState.inactive,
    );
    expect(
      CategoryEvolution.fromSummary(null).state,
      CategoryEvolutionState.unavailable,
    );
    expect(CategoryEvolution.fromSummary({'current': 100}).percent, isNull);
    expect(
      CategoryEvolution.fromSummary({
        'current': double.nan,
        'previous': 100,
      }).state,
      CategoryEvolutionState.unavailable,
    );
  });
  test(
    'Future months stay blank; zero amounts and unknown balances are distinct',
    () {
      final data = {'kind': 'categories', 'monthly': List.filled(12, 0)};
      final current = annualChartValues(data, 2026, DateTime.utc(2026, 4, 15));
      expect(current.take(4), everyElement(0));
      expect(current.skip(4), everyElement(isNull));
      expect(
        annualChartValues(
          data,
          2025,
          DateTime.utc(2026),
        ).whereType<double>().length,
        12,
      );
      expect(
        annualChartValues(data, 2027, DateTime.utc(2026)),
        everyElement(isNull),
      );
      expect(
        annualChartValues(
          {
            'kind': 'accounts',
            'closing': [null, 15, null],
          },
          2026,
          DateTime.utc(2026, 4),
        ),
        [null, 15, null, null, null, null, null, null, null, null, null, null],
      );
    },
  );
}
