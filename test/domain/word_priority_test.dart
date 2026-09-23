import 'dart:math';

import 'package:deutsch_review/domain/word_priority.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates success and weight from recent outcomes', () {
    expect(wordSuccessPercent(const []), 0);
    expect(wordSelectionWeight(const []), 10);
    expect(wordSuccessPercent(const [true, false]), 50);
    expect(wordSelectionWeight(const [true, false]), 6);
    expect(wordSelectionWeight(List<bool>.filled(10, true)), 1);
  });

  test('builds a queue without immediate repeats when possible', () {
    final queue = buildWeightedQueue(
      itemIds: const ['a', 'b', 'c'],
      recentOutcomes: const {},
      length: 100,
      random: Random(7),
    );

    expect(queue, hasLength(100));
    for (var index = 1; index < queue.length; index++) {
      expect(queue[index], isNot(queue[index - 1]));
    }
  });

  test('problem words are selected more often', () {
    final queue = buildWeightedQueue(
      itemIds: const ['problem', 'known', 'neutral'],
      recentOutcomes: {
        'problem': List<bool>.filled(10, false),
        'known': List<bool>.filled(10, true),
        'neutral': const [true, false],
      },
      length: 1000,
      random: Random(11),
    );

    expect(
      queue.where((id) => id == 'problem').length,
      greaterThan(queue.where((id) => id == 'known').length),
    );
  });
}
