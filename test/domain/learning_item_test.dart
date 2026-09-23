import 'package:deutsch_review/domain/learning_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wire names match content format version 1', () {
    expect(
      LearningItemType.values.map((type) => type.wireName),
      <String>[
        'word',
        'noun',
        'verb',
        'phrase',
        'sentence',
        'grammar_rule',
        'rule_example',
        'fill_gap',
        'word_order',
        'multiple_choice',
      ],
    );
  });

  test('all active items are available for review', () {
    final timestamp = DateTime.utc(2026, 9, 23);
    final activeItem = LearningItem(
      id: 'item-1',
      type: LearningItemType.word,
      level: 'A1.1',
      lesson: '1',
      topic: 'Begrüßung',
      learned: true,
      createdAt: timestamp,
      updatedAt: timestamp,
      sourceRef: 'Schritte plus Neu, A1.1, Lektion 1',
      content: const <String, Object?>{'prompt': 'Hallo'},
    );
    final unlearnedItem = LearningItem(
      id: 'item-2',
      type: LearningItemType.word,
      level: 'A1.1',
      lesson: '1',
      topic: 'Begrüßung',
      learned: false,
      createdAt: timestamp,
      updatedAt: timestamp,
      sourceRef: 'Schritte plus Neu, A1.1, Lektion 1',
      content: const <String, Object?>{'prompt': 'Guten Tag'},
    );
    final deletedItem = LearningItem(
      id: 'item-3',
      type: LearningItemType.word,
      level: 'A1.1',
      lesson: '1',
      topic: 'Begrüßung',
      learned: true,
      createdAt: timestamp,
      updatedAt: timestamp,
      deletedAt: timestamp,
      sourceRef: 'Schritte plus Neu, A1.1, Lektion 1',
      content: const <String, Object?>{'prompt': 'Tschüss'},
    );

    expect(activeItem.isAvailableForReview, isTrue);
    expect(unlearnedItem.isAvailableForReview, isTrue);
    expect(deletedItem.isAvailableForReview, isFalse);
  });
}
