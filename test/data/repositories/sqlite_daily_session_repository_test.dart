import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_daily_session_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/domain/daily_session.dart';
import 'package:deutsch_review/domain/grammar.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/domain/practice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates exactly five required sessions per day', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteDailySessionRepository(database);
    final now = DateTime.utc(2026, 9, 24, 10);

    final first = await repository.ensureDay(localDate: '2026-09-24', now: now);
    final second =
        await repository.ensureDay(localDate: '2026-09-24', now: now);

    expect(first.where((session) => session.isRequired), hasLength(5));
    expect(second.where((session) => session.isRequired), hasLength(5));
    expect(first.map((session) => session.id),
        second.map((session) => session.id));
  });

  test('records an answer and restores an unfinished queue', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final sessions = SqliteDailySessionRepository(database);
    final items = SqliteLearningItemRepository(database);
    final now = DateTime.utc(2026, 9, 24, 10);
    await items.save(_word(now));
    final planned = (await sessions.ensureDay(
      localDate: '2026-09-24',
      now: now,
    ))
        .first;
    await sessions.start(
      id: planned.id,
      queueItemIds: List<String>.filled(20, 'word-1'),
      now: now,
    );

    final updated = await sessions.recordAnswer(
      attempt: PracticeAttempt(
        id: 'attempt-1',
        itemId: 'word-1',
        sessionId: planned.id,
        answerText: 'lernen',
        correct: true,
        attemptedAt: now,
      ),
      remainingQueueItemIds: List<String>.filled(19, 'word-1'),
      now: now,
    );

    expect(updated.status, DailySessionStatus.inProgress);
    expect(updated.answeredCount, 1);
    expect(updated.queueItemIds, hasLength(19));
    expect((await sessions.findById(planned.id))!.queueItemIds, hasLength(19));

    var current = updated;
    for (var index = 2; index <= 20; index++) {
      current = await sessions.recordAnswer(
        attempt: PracticeAttempt(
          id: 'attempt-$index',
          itemId: 'word-1',
          sessionId: planned.id,
          answerText: 'lernen',
          correct: true,
          attemptedAt: now.add(Duration(minutes: index)),
        ),
        remainingQueueItemIds: List<String>.filled(20 - index, 'word-1'),
        now: now.add(Duration(minutes: index)),
      );
    }
    expect(current.status, DailySessionStatus.completed);
    expect(current.answeredCount, 20);
    expect(current.queueItemIds, isEmpty);
    expect(current.completedAt, isNotNull);
  });

  test('adds two grammar sessions only when grammar is available', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteDailySessionRepository(database);
    final now = DateTime.utc(2026, 9, 24, 10);

    final sessions = await repository.ensureDay(
      localDate: '2026-09-24',
      now: now,
      includeGrammar: true,
    );

    expect(sessions.where((session) => session.isRequired), hasLength(7));
    expect(
        sessions.where((session) => session.kind == DailySessionKind.grammar),
        hasLength(2));
    expect(
        sessions.firstWhere((session) => session.slot == 6).targetAnswers, 10);
  });

  test('records a grammar task atomically with all field attempts', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteDailySessionRepository(database);
    final now = DateTime.utc(2026, 9, 24, 10);
    final planned = (await repository.ensureDay(
      localDate: '2026-09-24',
      now: now,
      includeGrammar: true,
    ))
        .firstWhere((session) => session.slot == 6);
    await repository.start(
      id: planned.id,
      queueItemIds: List.generate(10, (index) => 'grammar-$index'),
      now: now,
    );

    final updated = await repository.recordGrammarTask(
      sessionId: planned.id,
      attempts: [
        GrammarAttempt(
          id: 'grammar-attempt-1',
          topicId: 'regular_present',
          exerciseId: 'grammar-0:ich',
          sessionId: planned.id,
          answerText: 'e',
          correct: true,
          attemptedAt: now,
        ),
        GrammarAttempt(
          id: 'grammar-attempt-2',
          topicId: 'regular_present',
          exerciseId: 'grammar-0:du',
          sessionId: planned.id,
          answerText: 'st',
          correct: true,
          attemptedAt: now,
        ),
      ],
      remainingQueueItemIds:
          List.generate(9, (index) => 'grammar-${index + 1}'),
      lastExerciseId: 'grammar-0',
      now: now,
    );

    expect(updated.answeredCount, 1);
    expect(updated.queueItemIds, hasLength(9));
    expect(
      database.connection
          .select('SELECT * FROM grammar_attempts WHERE session_id = ?', [
        planned.id,
      ]),
      hasLength(2),
    );
  });
}

LearningItem _word(DateTime now) {
  return LearningItem(
    id: 'word-1',
    type: LearningItemType.word,
    level: '',
    lesson: '',
    topic: '',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'manual',
    content: const {'german': 'lernen', 'translation_ru': 'учить'},
  );
}
