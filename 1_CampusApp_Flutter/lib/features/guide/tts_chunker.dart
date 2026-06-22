List<String> splitTtsChunks(
  String text, {
  int softLimit = 70,
  int hardLimit = 90,
}) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.isEmpty) return const [];

  final chunks = <String>[];
  final buffer = StringBuffer();
  final sentencePattern = RegExp(r'[^。！？!?；;\.]+[。！？!?；;\.]?');

  void flushBuffer() {
    final chunk = buffer.toString().trim();
    if (chunk.isNotEmpty) chunks.add(chunk);
    buffer.clear();
  }

  void addPart(String part) {
    final normalizedPart = part.trim();
    if (normalizedPart.isEmpty) return;
    final separatorLength = buffer.isEmpty ? 0 : 1;
    if (buffer.isNotEmpty &&
        buffer.length + separatorLength + normalizedPart.length > hardLimit) {
      flushBuffer();
    }
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(normalizedPart);
    if (buffer.length >= softLimit) {
      flushBuffer();
    }
  }

  List<String> splitLongSentence(String sentence) {
    if (sentence.length <= hardLimit) return [sentence];

    final parts = <String>[];
    final words = sentence.split(RegExp(r'\s+'));
    final current = StringBuffer();

    for (final word in words) {
      if (word.isEmpty) continue;
      if (current.isNotEmpty && current.length + word.length + 1 > hardLimit) {
        parts.add(current.toString().trim());
        current.clear();
      }
      if (word.length > hardLimit) {
        if (current.isNotEmpty) {
          parts.add(current.toString().trim());
          current.clear();
        }
        for (var start = 0; start < word.length; start += hardLimit) {
          final end = start + hardLimit < word.length
              ? start + hardLimit
              : word.length;
          parts.add(word.substring(start, end));
        }
      } else {
        if (current.isNotEmpty) current.write(' ');
        current.write(word);
      }
    }
    if (current.isNotEmpty) parts.add(current.toString().trim());
    return parts;
  }

  for (final match in sentencePattern.allMatches(normalized)) {
    final sentence = match.group(0)?.trim() ?? '';
    if (sentence.isEmpty) continue;
    for (final part in splitLongSentence(sentence)) {
      addPart(part);
    }
  }

  flushBuffer();
  if (chunks.isEmpty && normalized.isNotEmpty) return [normalized];
  return chunks;
}
