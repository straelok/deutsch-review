import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_practice_repository.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/domain/practice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists attempts and calculates problem-word statistics', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final items = SqliteLearningItemRepository(database);
    final practice = SqlitePracticeRepository(database);
    final now = DateTime.utc(2026, 9, 23, 10);
    await items.save(
      LearningItem(
        id: 'item-1',
        type: LearningItemType.word,
        level: 'A1.1',
        lesson: '1',
        topic: 'Schule',
        learned: true,
        createdAt: now,
        updatedAt: now,
        sourceRef: 'DAA',
        content: const {'german': 'lernen', 'translation_ru': 'учить'},
      ),
    );

    await practice.saveAttempt(
      PracticeAttempt(
        id: 'attempt-1',
        itemId: 'item-1',
        sessionId: 'session-1',
        answerText: 'leren',
        correct: false,
        attemptedAt: now,
      ),
    );
    await practice.saveAttempt(
      PracticeAttempt(
        id: 'attempt-2',
        itemId: 'item-1',
        sessionId: 'session-1',
        answerText: 'lernen',
        correct: true,
        attemptedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final summary = await practice.summary();
    expect(summary.attempts, 2);
    expect(summary.correct, 1);
    expect(summary.errors, 1);
    expect(summary.accuracy, 0.5);
    final itemSummary = await practice.summaryForItem('item-1');
    expect(itemSummary.attempts, 2);
    expect(itemSummary.correct, 1);
    expect(itemSummary.errors, 1);
    expect(itemSummary.accuracy, 0.5);
    expect((await practice.summaryForItem('unknown')).attempts, 0);
    final recent = await practice.recentOutcomes();
    expect(recent['item-1'], <bool>[true, false]);
    final problem = (await practice.problemItems()).single;
    expect(problem.item.id, 'item-1');
    expect(problem.errors, 1);
  });
}
