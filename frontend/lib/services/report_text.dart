/// Keep PDF rows bounded without discarding text, including imported values.
List<String> splitReportText(String text) {
  if (text.isEmpty) return [''];
  final chunks = <String>[];
  var buffer = <int>[];
  var newlines = 0;
  for (final rune in text.runes) {
    buffer.add(rune);
    if (rune == 10) newlines++;
    if (buffer.length >= 120 || newlines >= 5) {
      var end = buffer.length;
      // Prefer a word boundary; long unbroken identifiers still get split.
      if (rune != 10 && newlines < 5) {
        for (var i = buffer.length - 1; i >= 80; i--) {
          if (buffer[i] == 32 || buffer[i] == 10 || buffer[i] == 9) {
            end = i + 1;
            break;
          }
        }
      }
      chunks.add(String.fromCharCodes(buffer.take(end)));
      buffer = buffer.skip(end).toList();
      newlines = buffer.where((rune) => rune == 10).length;
    }
  }
  if (buffer.isNotEmpty) chunks.add(String.fromCharCodes(buffer));
  return chunks;
}
