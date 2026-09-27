import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/import_export/word_import_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 9, 24);
  final importedAt = DateTime.utc(2026, 9, 26);

  test('reimporting the same item does not create a duplicate', () {
    final existing = _word(
      id: 'local-id',
      german: 'lernen',
      translation: 'учить; изучать',
      createdAt: createdAt,
    );

    final plan = planWordImport(
      existing: [existing],
      imported: [existing],
      importedAt: importedAt,
    );

    expect(plan.additions, isEmpty);
    expect(plan.updates, isEmpty);
    expect(plan.skipped, 1);
  });

  test('updates matching German entry while preserving id and progress key',
      () {
    final existing = _word(
      id: 'local-id',
      german: 'lernen',
      translation: 'учить',
      createdAt: createdAt,
    );
    final incoming = _word(
      id: 'different-export-id',
      german: 'lernen',
      translation: 'учить; изучать',
      createdAt: importedAt,
    );

    final plan = planWordImport(
      existing: [existing],
      imported: [incoming],
      importedAt: importedAt,
    );

    expect(plan.additions, isEmpty);
    expect(plan.updates, hasLength(1));
    expect(plan.updates.single.id, 'local-id');
    expect(plan.updates.single.createdAt, createdAt);
    expect(
      plan.updates.single.content['translation_ru'],
      'учить; изучать',
    );
  });

  test('restores a deleted item when its stable id is imported again', () {
    final deleted = _word(
      id: 'stable-id',
      german: 'wohnen',
      translation: 'жить',
      createdAt: createdAt,
      deletedAt: importedAt.subtract(const Duration(days: 1)),
    );

    final plan = planWordImport(
      existing: [deleted],
      imported: [
        _word(
          id: 'stable-id',
          german: 'wohnen',
          translation: 'жить; проживать',
          createdAt: createdAt,
        ),
      ],
      importedAt: importedAt,
    );

    expect(plan.updates, hasLength(1));
    expect(plan.updates.single.deletedAt, isNull);
  });
}

LearningItem _word({
  required String id,
  required String german,
  required String translation,
  required DateTime createdAt,
  DateTime? deletedAt,
}) {
  return LearningItem(
    id: id,
    type: LearningItemType.verb,
    level: '',
    lesson: '',
    topic: '',
    learned: true,
    createdAt: createdAt,
    updatedAt: createdAt,
    deletedAt: deletedAt,
    sourceRef: 'json',
    content: {'german': german, 'translation_ru': translation},
  );
}
