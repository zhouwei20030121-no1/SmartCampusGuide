import 'package:flutter_test/flutter_test.dart';
import 'package:smart_campus_guide/features/guide/tts_chunker.dart';

void main() {
  test('splits long English guide text into bounded chunks', () {
    const text =
        "Hello, new students! I'm Xi Xiaodao, the AI virtual guide of Southwest University's smart campus navigation system. Right now, we're standing at the Graduate School Building. This building is the core hub for graduate education management on campus and an important starting point for your academic journey ahead.";

    final chunks = splitTtsChunks(text);

    expect(chunks.length, greaterThan(3));
    expect(chunks.first, 'Hello, new students!');
    expect(chunks.every((chunk) => chunk.length <= 90), isTrue);
    expect(chunks.join(''), contains('Graduate School Building.'));
  });
}
