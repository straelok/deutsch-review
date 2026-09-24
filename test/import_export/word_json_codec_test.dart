import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/import_export/word_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = WordJsonCodec();
  final now = DateTime.utc(2026, 9, 24, 12);

  test('exports and imports words without internal legacy fields', () {
    final source = LearningItem(
      id: 'word-1',
      type: LearningItemType.word,
      level: '',
      lesson: '',
      topic: '',
      learned: true,
      createdAt: now,
      updatedAt: now,
      sourceRef: 'manual',
      content: const {
        'german': 'lernen',
        'translation_ru': 'учить',
        'example': 'Ich lerne Deutsch.',
        'note': 'regelmäßig',
      },
    );

    final json = codec.encode([source], exportedAt: now);
    final restored = codec.decode(json, importedAt: now).single;

    expect(restored.id, source.id);
    expect(restored.type, LearningItemType.word);
    expect(restored.content, source.content);
    expect(json, isNot(contains('source_ref')));
    expect(json, isNot(contains('learned')));
  });

  test('imports a minimal noun and creates missing metadata', () {
    final restored = codec.decode(
      '''
      {
        "format_version": 1,
        "words": [
          {
            "type": "noun",
            "german": "Tisch",
            "translation_ru": "стол",
            "article": "der",
            "plural": "Tische"
          }
        ]
      }
      ''',
      importedAt: now,
    ).single;

    expect(restored.id, isNotEmpty);
    expect(restored.content['article'], 'der');
    expect(restored.content['plural'], 'Tische');
    expect(restored.createdAt, now);
  });

  test('rejects the whole package when a required field is missing', () {
    expect(
      () => codec.decode(
        '{"format_version":1,"words":[{"type":"word"}]}',
        importedAt: now,
      ),
      throwsFormatException,
    );
  });
}
