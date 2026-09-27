import 'dart:io';

import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/domain/learning_item_display.dart';
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

  test('exports verbs in version 2 and still imports version 1', () {
    final verb = LearningItem(
      id: 'verb-1',
      type: LearningItemType.verb,
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
      },
    );

    final json = codec.encode([verb], exportedAt: now);
    final restored = codec.decode(json, importedAt: now).single;

    expect(json, contains('"format_version": 2'));
    expect(restored.type, LearningItemType.verb);
    expect(restored.content['german'], 'lernen');
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

  test('supports Russian alternatives but rejects multiple German entries', () {
    final restored = codec
        .decode(
          '{"format_version":2,"words":[{"type":"word",'
          '"german":"lernen","translation_ru":"учить; изучать"}]}',
          importedAt: now,
        )
        .single;
    expect(restored.content['translation_ru'], 'учить; изучать');

    expect(
      () => codec.decode(
        '{"format_version":2,"words":[{"type":"word",'
        '"german":"lernen; studieren","translation_ru":"учить"}]}',
        importedAt: now,
      ),
      throwsFormatException,
    );
  });

  test('validates the bundled starter vocabulary', () {
    final source = File(
      'content/worttrieb-words-2026-09-26.json',
    ).readAsStringSync();
    final items = codec.decode(source, importedAt: now);
    final keys = items
        .map(
          (item) => '${item.type.wireName}:'
              '${learningItemGerman(item).trim()}',
        )
        .toSet();

    expect(items, hasLength(271));
    expect(keys, hasLength(items.length));
    expect(
      items.any((item) => item.content['german'] == 'Supermarkt'),
      isTrue,
    );
    expect(
      items.every(
        (item) => (item.content['translation_ru'] as String)
            .split(';')
            .every((part) => part.trim().isNotEmpty),
      ),
      isTrue,
    );
  });
}
