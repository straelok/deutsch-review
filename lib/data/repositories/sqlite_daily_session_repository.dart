import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/daily_session.dart';
import '../../domain/id_generator.dart';
import '../../domain/grammar.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/daily_session_repository.dart';
import '../database/app_database.dart';

final class SqliteDailySessionRepository implements DailySessionRepository {
  const SqliteDailySessionRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<DailySession>> ensureDay({
    required String localDate,
    required DateTime now,
    bool includeGrammar = false,
  }) async {
    final timestamp = now.toUtc().toIso8601String();
    database.connection.execute('BEGIN IMMEDIATE');
    try {
      for (var slot = 1; slot <= 5; slot++) {
        database.connection.execute(
          '''
          INSERT OR IGNORE INTO daily_sessions (
            id, local_date, slot, kind, status, target_answers, answered_count,
            queue_json, last_item_id, created_at, updated_at, completed_at
          ) VALUES (?, ?, ?, 'vocabulary', 'planned', 20, 0, '[]', NULL, ?, ?, NULL)
          ''',
          <Object?>[newUuidV4(), localDate, slot, timestamp, timestamp],
        );
      }
      if (includeGrammar) {
        for (var slot = 6; slot <= 7; slot++) {
          database.connection.execute(
            '''
            INSERT OR IGNORE INTO daily_sessions (
              id, local_date, slot, kind, status, target_answers, answered_count,
              queue_json, last_item_id, created_at, updated_at, completed_at
            ) VALUES (?, ?, ?, 'grammar', 'planned', 10, 0, '[]', NULL, ?, ?, NULL)
            ''',
            <Object?>[newUuidV4(), localDate, slot, timestamp, timestamp],
          );
        }
      }
      database.connection.execute('COMMIT');
    } catch (_) {
      database.connection.execute('ROLLBACK');
      rethrow;
    }
    return _findForDate(localDate);
  }

  @override
  Future<DailySession?> findById(String id) async {
    final rows = database.connection.select(
      'SELECT * FROM daily_sessions WHERE id = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : _mapRow(rows.single);
  }

  @override
  Future<DailySession> createExtra({
    required String localDate,
    required DateTime now,
  }) async {
    final id = newUuidV4();
    final timestamp = now.toUtc().toIso8601String();
    database.connection.execute(
      '''
      INSERT INTO daily_sessions (
        id, local_date, slot, kind, status, target_answers, answered_count,
        queue_json, last_item_id, created_at, updated_at, completed_at
      ) VALUES (?, ?, NULL, 'vocabulary', 'planned', 20, 0, '[]', NULL, ?, ?, NULL)
      ''',
      <Object?>[id, localDate, timestamp, timestamp],
    );
    return (await findById(id))!;
  }

  @override
  Future<DailySession> start({
    required String id,
    required List<String> queueItemIds,
    required DateTime now,
  }) async {
    database.connection.execute(
      '''
      UPDATE daily_sessions
      SET status = 'in_progress', queue_json = ?, updated_at = ?
      WHERE id = ? AND status != 'completed'
      ''',
      <Object?>[
        jsonEncode(queueItemIds),
        now.toUtc().toIso8601String(),
        id,
      ],
    );
    return (await findById(id))!;
  }

  @override
  Future<DailySession> recordAnswer({
    required PracticeAttempt attempt,
    required List<String> remainingQueueItemIds,
    required DateTime now,
  }) async {
    final session = await findById(attempt.sessionId);
    if (session == null || session.isComplete) {
      throw StateError('Cannot record an answer for this session.');
    }
    final answeredCount = session.answeredCount + 1;
    final completed = answeredCount >= session.targetAnswers;
    final timestamp = now.toUtc().toIso8601String();

    database.connection.execute('BEGIN IMMEDIATE');
    try {
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
      database.connection.execute(
        '''
        UPDATE daily_sessions
        SET status = ?, answered_count = ?, queue_json = ?, last_item_id = ?,
            updated_at = ?, completed_at = ?
        WHERE id = ?
        ''',
        <Object?>[
          completed ? 'completed' : 'in_progress',
          answeredCount,
          jsonEncode(completed ? const <String>[] : remainingQueueItemIds),
          attempt.itemId,
          timestamp,
          completed ? timestamp : null,
          session.id,
        ],
      );
      database.connection.execute('COMMIT');
    } catch (_) {
      database.connection.execute('ROLLBACK');
      rethrow;
    }
    return (await findById(session.id))!;
  }

  @override
  Future<DailySession> recordGrammarTask({
    required String sessionId,
    required List<GrammarAttempt> attempts,
    required List<String> remainingQueueItemIds,
    required String lastExerciseId,
    required DateTime now,
  }) async {
    final session = await findById(sessionId);
    if (session == null ||
        session.isComplete ||
        session.kind != DailySessionKind.grammar ||
        attempts.isEmpty) {
      throw StateError('Cannot record a grammar task for this session.');
    }
    final answeredCount = session.answeredCount + 1;
    final completed = answeredCount >= session.targetAnswers;
    final timestamp = now.toUtc().toIso8601String();

    database.connection.execute('BEGIN IMMEDIATE');
    try {
      for (final attempt in attempts) {
        database.connection.execute(
          '''
          INSERT INTO grammar_attempts (
            id, topic_id, exercise_id, session_id, answer_text, correct,
            attempted_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?)
          ''',
          <Object?>[
            attempt.id,
            attempt.topicId,
            attempt.exerciseId,
            attempt.sessionId,
            attempt.answerText,
            attempt.correct ? 1 : 0,
            attempt.attemptedAt.toUtc().toIso8601String(),
          ],
        );
      }
      database.connection.execute(
        '''
        UPDATE daily_sessions
        SET status = ?, answered_count = ?, queue_json = ?, last_item_id = ?,
            updated_at = ?, completed_at = ?
        WHERE id = ?
        ''',
        <Object?>[
          completed ? 'completed' : 'in_progress',
          answeredCount,
          jsonEncode(completed ? const <String>[] : remainingQueueItemIds),
          lastExerciseId,
          timestamp,
          completed ? timestamp : null,
          session.id,
        ],
      );
      database.connection.execute('COMMIT');
    } catch (_) {
      database.connection.execute('ROLLBACK');
      rethrow;
    }
    return (await findById(session.id))!;
  }

  List<DailySession> _findForDate(String localDate) {
    final rows = database.connection.select(
      '''
      SELECT * FROM daily_sessions
      WHERE local_date = ?
      ORDER BY slot IS NULL, slot, created_at
      ''',
      <Object?>[localDate],
    );
    return rows.map(_mapRow).toList(growable: false);
  }

  static DailySession _mapRow(Row row) {
    final decodedQueue = jsonDecode(row['queue_json'] as String);
    if (decodedQueue is! List) {
      throw const FormatException('queue_json must contain a JSON array');
    }
    return DailySession(
      id: row['id'] as String,
      localDate: row['local_date'] as String,
      slot: row['slot'] as int?,
      kind: DailySessionKind.fromWireName(row['kind'] as String),
      status: DailySessionStatus.fromWireName(row['status'] as String),
      targetAnswers: row['target_answers'] as int,
      answeredCount: row['answered_count'] as int,
      queueItemIds: decodedQueue.cast<String>(),
      lastItemId: row['last_item_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      completedAt: switch (row['completed_at']) {
        final String value => DateTime.parse(value).toUtc(),
        _ => null,
      },
    );
  }
}
