import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_grammar_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists learned grammar topics and returns empty statistics',
      () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteGrammarRepository(database);
    final now = DateTime.utc(2026, 9, 24, 12);

    await repository.setLearned(
      topicId: 'regular_present',
      learned: true,
      now: now,
    );

    final progress = await repository.progress();
    final summary = await repository.summary('regular_present');
    expect(progress['regular_present']?.learned, isTrue);
    expect(summary.attempts, 0);
  });

  test('separates daily number and grammar statistics', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteGrammarRepository(database);
    final day = DateTime(2026, 9, 28);

    void addAttempt({
      required String id,
      required String topicId,
      required bool correct,
      required DateTime attemptedAt,
    }) {
      database.connection.execute(
        '''
        INSERT INTO grammar_attempts (
          id, topic_id, exercise_id, session_id,
          answer_text, correct, attempted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          id,
          topicId,
          'exercise-$id',
          'session-$id',
          '',
          correct ? 1 : 0,
          attemptedAt.toUtc().toIso8601String(),
        ],
      );
    }

    addAttempt(
      id: 'number-correct',
      topicId: 'numbers',
      correct: true,
      attemptedAt: DateTime(2026, 9, 28, 9),
    );
    addAttempt(
      id: 'number-error',
      topicId: 'numbers',
      correct: false,
      attemptedAt: DateTime(2026, 9, 28, 10),
    );
    addAttempt(
      id: 'grammar-error',
      topicId: 'sein',
      correct: false,
      attemptedAt: DateTime(2026, 9, 28, 11),
    );
    addAttempt(
      id: 'next-day',
      topicId: 'haben',
      correct: true,
      attemptedAt: DateTime(2026, 9, 29),
    );

    final numbers = await repository.summaryForDay(day, numbers: true);
    final grammar = await repository.summaryForDay(day, numbers: false);
    expect(numbers.attempts, 2);
    expect(numbers.correct, 1);
    expect(grammar.attempts, 1);
    expect(grammar.correct, 0);
  });
}
