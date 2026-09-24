import '../../domain/grammar.dart';
import '../../domain/repositories/grammar_repository.dart';
import '../database/app_database.dart';

final class SqliteGrammarRepository implements GrammarRepository {
  const SqliteGrammarRepository(this.database);

  final AppDatabase database;

  @override
  Future<Map<String, GrammarTopicProgress>> progress() async {
    final rows = database.connection.select(
      'SELECT * FROM grammar_topic_progress ORDER BY topic_id',
    );
    return <String, GrammarTopicProgress>{
      for (final row in rows)
        row['topic_id'] as String: GrammarTopicProgress(
          topicId: row['topic_id'] as String,
          learned: (row['learned'] as int) == 1,
          updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
        ),
    };
  }

  @override
  Future<void> setLearned({
    required String topicId,
    required bool learned,
    required DateTime now,
  }) async {
    database.connection.execute(
      '''
      INSERT INTO grammar_topic_progress (topic_id, learned, updated_at)
      VALUES (?, ?, ?)
      ON CONFLICT(topic_id) DO UPDATE SET
        learned = excluded.learned,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        topicId,
        learned ? 1 : 0,
        now.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<GrammarSummary> summary(String topicId) async {
    final row = database.connection.select(
      '''
      SELECT COUNT(*) AS attempts, COALESCE(SUM(correct), 0) AS correct
      FROM grammar_attempts
      WHERE topic_id = ?
      ''',
      <Object?>[topicId],
    ).single;
    return GrammarSummary(
      attempts: row['attempts'] as int,
      correct: row['correct'] as int,
    );
  }

  @override
  Future<Map<String, List<bool>>> recentOutcomes({
    int limitPerTopic = 10,
  }) async {
    final rows = database.connection.select('''
      SELECT topic_id, correct
      FROM grammar_attempts
      ORDER BY attempted_at DESC, id DESC
    ''');
    final outcomes = <String, List<bool>>{};
    for (final row in rows) {
      final topicId = row['topic_id'] as String;
      final values = outcomes.putIfAbsent(topicId, () => <bool>[]);
      if (values.length < limitPerTopic) {
        values.add((row['correct'] as int) == 1);
      }
    }
    return outcomes;
  }
}
