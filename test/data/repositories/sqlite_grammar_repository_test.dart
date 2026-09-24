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
}
