import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/learning_item.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/practice_repository.dart';
import '../database/app_database.dart';

final class SqlitePracticeRepository implements PracticeRepository {
  const SqlitePracticeRepository(this.database);

  final AppDatabase database;

  @override
  Future<void> saveAttempt(PracticeAttempt attempt) async {
    database.connection.execute(
      '''
      INSERT INTO practice_attempts (
        id, item_id, session_id, answer_text, correct, attempted_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        attempt.id,
        attempt.itemId,
        attempt.sessionId,
        attempt.answerText,
        attempt.correct ? 1 : 0,
        attempt.attemptedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<PracticeSummary> summary() async {
    final row = database.connection.select('''
      SELECT COUNT(*) AS attempts, COALESCE(SUM(correct), 0) AS correct
      FROM practice_attempts
    ''').single;
    return PracticeSummary(
      attempts: row['attempts'] as int,
      correct: row['correct'] as int,
    );
  }

  @override
  Future<PracticeSummary> summaryForItem(String itemId) async {
    final row = database.connection.select(
      '''
      SELECT COUNT(*) AS attempts, COALESCE(SUM(correct), 0) AS correct
      FROM practice_attempts
      WHERE item_id = ?
      ''',
      <Object?>[itemId],
    ).single;
    return PracticeSummary(
      attempts: row['attempts'] as int,
      correct: row['correct'] as int,
    );
  }

  @override
  Future<List<ItemPracticeSummary>> problemItems({int limit = 20}) async {
    final rows = database.connection.select(
      '''
      SELECT
        learning_items.*,
        COUNT(practice_attempts.id) AS attempt_count,
        COALESCE(SUM(practice_attempts.correct), 0) AS correct_count
      FROM practice_attempts
      JOIN learning_items ON learning_items.id = practice_attempts.item_id
      WHERE learning_items.deleted_at IS NULL
      GROUP BY learning_items.id
      HAVING COUNT(practice_attempts.id) - SUM(practice_attempts.correct) > 0
      ORDER BY
        COUNT(practice_attempts.id) - SUM(practice_attempts.correct) DESC,
        CAST(SUM(practice_attempts.correct) AS REAL) /
          COUNT(practice_attempts.id) ASC,
        MAX(practice_attempts.attempted_at) DESC
      LIMIT ?
      ''',
      <Object?>[limit],
    );
    return rows.map(_mapSummary).toList(growable: false);
  }

  static ItemPracticeSummary _mapSummary(Row row) {
    final decodedContent = jsonDecode(row['content_json'] as String);
    if (decodedContent is! Map<String, Object?>) {
      throw const FormatException('content_json must contain a JSON object');
    }
    return ItemPracticeSummary(
      item: LearningItem(
        id: row['id'] as String,
        type: LearningItemType.fromWireName(row['type'] as String),
        level: row['level'] as String,
        lesson: row['lesson'] as String,
        topic: row['topic'] as String,
        learned: (row['learned'] as int) == 1,
        createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
        updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
        sourceRef: row['source_ref'] as String,
        content: decodedContent,
      ),
      attempts: row['attempt_count'] as int,
      correct: row['correct_count'] as int,
    );
  }
}
