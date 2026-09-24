import 'dart:io';

import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves, updates and soft-deletes a learning item', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteLearningItemRepository(database);
    final createdAt = DateTime.utc(2026, 9, 23, 10);
    final item = _word(id: 'item-1', createdAt: createdAt);

    await repository.save(item);

    final stored = await repository.findById(item.id);
    expect(stored?.content['german'], 'der Tisch');
    expect(stored?.isAvailableForReview, isTrue);

    await repository.save(
      _word(
        id: item.id,
        createdAt: createdAt,
        updatedAt: createdAt.add(const Duration(minutes: 5)),
        translation: 'стол; таблица',
      ),
    );
    final updated = await repository.findById(item.id);
    expect(updated?.content['translation_ru'], 'стол; таблица');
    expect((await repository.findActive()).single.id, item.id);

    final deletedAt = createdAt.add(const Duration(hours: 1));
    expect(
      await repository.softDelete(id: item.id, deletedAt: deletedAt),
      isTrue,
    );
    expect(await repository.findActive(), isEmpty);
    expect((await repository.findById(item.id))?.deletedAt, deletedAt);
    expect(
      await repository.softDelete(id: item.id, deletedAt: deletedAt),
      isFalse,
    );
    expect(
      await repository.restore(
        id: item.id,
        restoredAt: deletedAt.add(const Duration(minutes: 1)),
      ),
      isTrue,
    );
    expect((await repository.findActive()).single.id, item.id);
  });

  test('persists items after reopening a file database', () async {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}dictionary.sqlite';
    final createdAt = DateTime.utc(2026, 9, 23, 10);

    final firstDatabase = AppDatabase.open(path);
    await SqliteLearningItemRepository(
      firstDatabase,
    ).save(_word(id: 'persistent-item', createdAt: createdAt));
    firstDatabase.close();

    final reopenedDatabase = AppDatabase.open(path);
    addTearDown(reopenedDatabase.close);
    final restored = await SqliteLearningItemRepository(
      reopenedDatabase,
    ).findById('persistent-item');

    expect(restored?.content['german'], 'der Tisch');
  });

  test('saves an imported list in one operation', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteLearningItemRepository(database);
    final createdAt = DateTime.utc(2026, 9, 24, 10);

    await repository.saveAll([
      _word(id: 'import-1', createdAt: createdAt),
      _word(id: 'import-2', createdAt: createdAt),
    ]);

    expect(await repository.findActive(), hasLength(2));
  });
}

LearningItem _word({
  required String id,
  required DateTime createdAt,
  DateTime? updatedAt,
  String translation = 'стол',
}) {
  return LearningItem(
    id: id,
    type: LearningItemType.noun,
    level: 'A1.1',
    lesson: '1',
    topic: 'Gegenstände',
    learned: true,
    createdAt: createdAt,
    updatedAt: updatedAt ?? createdAt,
    sourceRef: 'DAA, Schritte plus Neu, A1.1',
    content: <String, Object?>{
      'german': 'der Tisch',
      'translation_ru': translation,
      'plural': 'die Tische',
    },
  );
}
