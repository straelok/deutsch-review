import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_practice_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_daily_session_repository.dart';
import 'package:deutsch_review/domain/daily_session.dart';
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
    final recent = await practice.recentOutcomes();
    expect(recent['item-1'], <bool>[true, false]);
    final problem = (await practice.problemItems()).single;
    expect(problem.item.id, 'item-1');
    expect(problem.errors, 1);

    for (var index = 3; index <= 12; index++) {
      await practice.saveAttempt(
        PracticeAttempt(
          id: 'attempt-$index',
          itemId: 'item-1',
          sessionId: 'session-2',
          answerText: 'lernen',
          correct: index <= 9,
          attemptedAt: now.add(Duration(minutes: index)),
        ),
      );
    }
    final statistics = (await practice.statisticsByItem())['item-1']!;
    expect(statistics.recent.attempts, 10);
    expect(statistics.recent.correct, 7);
    expect(statistics.allTime.attempts, 12);
    expect(statistics.allTime.correct, 8);
  });

  test('calculates vocabulary statistics for one local day', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final items = SqliteLearningItemRepository(database);
    final practice = SqlitePracticeRepository(database);
    final day = DateTime(2026, 9, 28);
    await items.save(
      LearningItem(
        id: 'item-1',
        type: LearningItemType.word,
        level: '',
        lesson: '',
        topic: '',
        learned: true,
        createdAt: day.toUtc(),
        updatedAt: day.toUtc(),
        sourceRef: 'test',
        content: const {'german': 'lernen', 'translation_ru': 'учить'},
      ),
    );

    for (final entry in <(String, DateTime, bool)>[
      ('previous', DateTime(2026, 9, 27, 23, 59), false),
      ('today-correct', DateTime(2026, 9, 28, 9), true),
      ('today-error', DateTime(2026, 9, 28, 20), false),
      ('next', DateTime(2026, 9, 29), true),
    ]) {
      await practice.saveAttempt(
        PracticeAttempt(
          id: entry.$1,
          itemId: 'item-1',
          sessionId: 'session-1',
          answerText: '',
          correct: entry.$3,
          attemptedAt: entry.$2.toUtc(),
        ),
      );
    }

    final summary = await practice.summaryForDay(day);
    expect(summary.attempts, 2);
    expect(summary.correct, 1);
    expect(summary.errors, 1);
  });

  test('ignores assisted successes but keeps assisted failures', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 10, 14, 10);
    await SqliteLearningItemRepository(database).save(
      LearningItem(
        id: 'item-1',
        type: LearningItemType.word,
        level: '',
        lesson: '',
        topic: '',
        learned: true,
        createdAt: now,
        updatedAt: now,
        sourceRef: 'test',
        content: const {'german': 'lernen', 'translation_ru': 'учить'},
      ),
    );
    final sessions = SqliteDailySessionRepository(database);
    final session = await sessions.createExtra(
      localDate: '2026-10-14',
      now: now,
      kind: DailySessionKind.easyVocabularyToGerman,
    );
    final practice = SqlitePracticeRepository(database);
    await practice.saveAttempt(
      PracticeAttempt(
        id: 'wrong',
        itemId: 'item-1',
        sessionId: session.id,
        answerText: 'leren',
        correct: false,
        attemptedAt: now,
      ),
    );
    await practice.saveAttempt(
      PracticeAttempt(
        id: 'correct',
        itemId: 'item-1',
        sessionId: session.id,
        answerText: 'lernen',
        correct: true,
        attemptedAt: now.add(const Duration(minutes: 1)),
      ),
    );

    final summary = await practice.summary();
    final statistics = (await practice.statisticsByItem())['item-1']!;
    expect(summary.attempts, 1);
    expect(summary.correct, 0);
    expect(statistics.allTime.attempts, 1);
    expect(statistics.allTime.correct, 0);
    expect(await practice.recentOutcomes(), {
      'item-1': <bool>[false],
    });
  });

  test('groups mastery statistics by translation direction', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final now = DateTime.utc(2026, 10, 14, 10);
    await SqliteLearningItemRepository(database).save(
      LearningItem(
        id: 'item-1',
        type: LearningItemType.word,
        level: '',
        lesson: '',
        topic: '',
        learned: true,
        createdAt: now,
        updatedAt: now,
        sourceRef: 'test',
        content: const {'german': 'lernen', 'translation_ru': 'учить'},
      ),
    );
    final sessions = SqliteDailySessionRepository(database);
    final toGerman = await sessions.createExtra(
      localDate: '2026-10-14',
      now: now,
      kind: DailySessionKind.marathonToGerman,
    );
    final toRussian = await sessions.createExtra(
      localDate: '2026-10-14',
      now: now,
      kind: DailySessionKind.marathonToRussian,
    );
    final practice = SqlitePracticeRepository(database);
    await practice.saveAttempt(
      PracticeAttempt(
        id: 'to-german-error',
        itemId: 'item-1',
        sessionId: toGerman.id,
        answerText: '',
        correct: false,
        attemptedAt: now,
      ),
    );
    await practice.saveAttempt(
      PracticeAttempt(
        id: 'to-russian-correct',
        itemId: 'item-1',
        sessionId: toRussian.id,
        answerText: 'учить',
        correct: true,
        attemptedAt: now,
      ),
    );

    final summary = await practice.directionSummary(localDay: now.toLocal());
    expect(summary.toGerman.attempts, 1);
    expect(summary.toGerman.correct, 0);
    expect(summary.toRussian.attempts, 1);
    expect(summary.toRussian.correct, 1);
  });
}
