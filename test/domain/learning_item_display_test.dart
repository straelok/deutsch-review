import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/domain/learning_item_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats regular and umlaut noun plurals compactly', () {
    expect(
      learningItemGermanWithPlural(_noun('Wind', 'der', 'Winde')),
      'der Wind, -e',
    );
    expect(
      learningItemGermanWithPlural(_noun('Radio', 'das', 'Radios')),
      'das Radio, -s',
    );
    expect(
      learningItemGermanWithPlural(_noun('Garten', 'der', 'Gärten')),
      'der Garten, -̈',
    );
    expect(
      learningItemGermanWithPlural(_noun('Stadt', 'die', 'Städte')),
      'die Stadt, -̈e',
    );
  });

  test('shows unchanged, missing and irregular plurals clearly', () {
    expect(
      learningItemGermanWithPlural(_noun('Würstchen', 'das', 'Würstchen')),
      'das Würstchen, -',
    );
    expect(
      learningItemGermanWithPlural(_noun('Hunger', 'der', '—')),
      'der Hunger, —',
    );
    expect(
      learningItemGermanWithPlural(_noun('Museum', 'das', 'Museen')),
      'das Museum, die Museen',
    );
  });
}

LearningItem _noun(String german, String article, String plural) {
  final now = DateTime.utc(2026, 10, 11);
  return LearningItem(
    id: german,
    type: LearningItemType.noun,
    level: 'A1.1',
    lesson: '6',
    topic: 'test',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'test',
    content: {
      'german': german,
      'article': article,
      'plural': plural,
      'translation_ru': 'тест',
    },
  );
}
