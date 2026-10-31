import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/models/category_filter.dart';

void main() {
  test(
    'Name search ignores accents; amount bounds include zero and endpoints',
    () {
      const filter = CategoryFilter(
        query: ' electricite ',
        minimum: 0,
        maximum: 100,
      );
      expect(filter.matches('ÉLECTRICITÉ', 0), isTrue);
      expect(filter.matches('Électricité', 100), isTrue);
      expect(filter.matches('Électricité', 100.01), isFalse);
      expect(filter.matches('Gaz', 10), isFalse);
      expect(const CategoryFilter(minimum: 50).matches('Gaz', 49.99), isFalse);
      expect(const CategoryFilter().matches('Catégorie inutilisée', 0), isTrue);
    },
  );

  test('Name and total sorting are deterministic, including equal amounts', () {
    const input = [
      (name: 'Gaz', total: 50.0),
      (name: 'Électricité', total: 20.0),
      (name: 'Alimentation', total: 50.0),
    ];
    for (final entry in {
      CategoryOrder.nameAscending: ['Alimentation', 'Électricité', 'Gaz'],
      CategoryOrder.nameDescending: ['Gaz', 'Électricité', 'Alimentation'],
      CategoryOrder.amountAscending: ['Électricité', 'Alimentation', 'Gaz'],
      CategoryOrder.amountDescending: ['Alimentation', 'Gaz', 'Électricité'],
    }.entries) {
      final filter = CategoryFilter(order: entry.key);
      final result = [...input]
        ..sort((a, b) => filter.compare(a.name, a.total, b.name, b.total));
      expect(result.map((e) => e.name).toList(), entry.value);
    }
  });
}
