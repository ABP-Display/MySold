import 'package:flutter_test/flutter_test.dart';
import 'package:mysold/services/report_text.dart';

void main() {
  test('Short values and empty cells are unchanged', () {
    expect(splitReportText('Compte titres'), ['Compte titres']);
    expect(splitReportText(''), ['']);
  });
  test('Long imported descriptions stay complete and bounded', () {
    final text = List.filled(200, 'Paiement récurrent 🏠\n').join();
    final chunks = splitReportText(text);
    expect(chunks.join(), text);
    for (final chunk in chunks) {
      expect(chunk.runes.length, lessThanOrEqualTo(120));
      expect('\n'.allMatches(chunk).length, lessThanOrEqualTo(5));
      expect(chunk.contains('\uFFFD'), isFalse);
    }
  });
  test('Unbroken values and newline-only values cannot create a tall row', () {
    for (final text in [
      List.filled(2000, 'É').join(),
      List.filled(100, '\n').join(),
    ]) {
      final chunks = splitReportText(text);
      expect(chunks.join(), text);
      expect(
        chunks.every(
          (part) =>
              part.runes.length <= 120 && '\n'.allMatches(part).length <= 5,
        ),
        isTrue,
      );
    }
  });
}
