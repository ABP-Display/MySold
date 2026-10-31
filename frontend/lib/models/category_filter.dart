enum CategoryOrder {
  nameAscending,
  nameDescending,
  amountAscending,
  amountDescending,
}

String categorySearchKey(String value) {
  var text = value.trim().toLowerCase();
  const accents = {
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
  };
  accents.forEach((from, to) => text = text.replaceAll(from, to));
  return text;
}

class CategoryFilter {
  final String query;
  final double? minimum, maximum;
  final CategoryOrder order;
  const CategoryFilter({
    this.query = '',
    this.minimum,
    this.maximum,
    this.order = CategoryOrder.nameAscending,
  });

  bool matches(String name, double total) =>
      categorySearchKey(name).contains(categorySearchKey(query)) &&
      (minimum == null || total >= minimum!) &&
      (maximum == null || total <= maximum!);

  int compare(String nameA, double amountA, String nameB, double amountB) {
    final names = categorySearchKey(nameA).compareTo(categorySearchKey(nameB));
    return switch (order) {
      CategoryOrder.nameAscending => names,
      CategoryOrder.nameDescending => -names,
      CategoryOrder.amountAscending =>
        amountA == amountB ? names : amountA.compareTo(amountB),
      CategoryOrder.amountDescending =>
        amountA == amountB ? names : amountB.compareTo(amountA),
    };
  }
}
