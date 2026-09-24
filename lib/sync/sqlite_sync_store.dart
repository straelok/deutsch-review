import 'dart:convert';

import '../data/database/app_database.dart';

final class SqliteSyncStore {
  const SqliteSyncStore(this.database);

  final AppDatabase database;

  String? readNickname() => _readSetting('sync_nickname');

  DateTime? readLastSuccess() {
    final value = _readSetting('sync_last_success');
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  void saveNickname(String nickname) =>
      _writeSetting('sync_nickname', nickname);

  void clearNickname() {
    database.connection.execute(
      "DELETE FROM app_settings WHERE key IN ('sync_nickname', 'sync_last_success')",
    );
  }

  void saveLastSuccess(DateTime value) {
    _writeSetting('sync_last_success', value.toUtc().toIso8601String());
  }

  Map<String, Object?> buildPayload() {
    return <String, Object?>{
      'version': 2,
      'items': database.connection.select('''
        SELECT * FROM learning_items ORDER BY id
      ''').map(_itemToJson).toList(growable: false),
      'attempts': database.connection.select('''
        SELECT * FROM practice_attempts ORDER BY id
      ''').map(_attemptToJson).toList(growable: false),
      'sessions': database.connection.select('''
        SELECT * FROM daily_sessions ORDER BY local_date, slot, id
      ''').map(_sessionToJson).toList(growable: false),
      'grammarProgress': database.connection.select('''
        SELECT * FROM grammar_topic_progress ORDER BY topic_id
      ''').map(_grammarProgressToJson).toList(growable: false),
      'grammarAttempts': database.connection.select('''
        SELECT * FROM grammar_attempts ORDER BY id
      ''').map(_grammarAttemptToJson).toList(growable: false),
    };
  }

  void mergePayload(Map<String, Object?> payload) {
    if (payload['version'] != 1 && payload['version'] != 2) {
      throw const FormatException('Unsupported sync payload version.');
    }
    final items = _objectList(payload['items'], 'items');
    final attempts = _objectList(payload['attempts'], 'attempts');
    final sessions = _objectList(payload['sessions'], 'sessions');
    final grammarProgress = payload['grammarProgress'] == null
        ? const <Map<String, Object?>>[]
        : _objectList(payload['grammarProgress'], 'grammarProgress');
    final grammarAttempts = payload['grammarAttempts'] == null
        ? const <Map<String, Object?>>[]
        : _objectList(payload['grammarAttempts'], 'grammarAttempts');

    database.connection.execute('BEGIN IMMEDIATE');
    try {
      for (final item in items) {
        _mergeItem(item);
      }
      for (final attempt in attempts) {
        _mergeAttempt(attempt);
      }
      for (final session in sessions) {
        _mergeSession(session);
      }
      for (final progress in grammarProgress) {
        _mergeGrammarProgress(progress);
      }
      for (final attempt in grammarAttempts) {
        _mergeGrammarAttempt(attempt);
      }
      database.connection.execute('COMMIT');
    } catch (_) {
      database.connection.execute('ROLLBACK');
      rethrow;
    }
  }

  void _mergeItem(Map<String, Object?> item) {
    final id = _string(item, 'id');
    final updatedAt = _dateString(item, 'updatedAt');
    final existing = database.connection.select(
      'SELECT updated_at FROM learning_items WHERE id = ?',
      <Object?>[id],
    );
    if (existing.isNotEmpty &&
        DateTime.parse(existing.single['updated_at'] as String)
            .isAfter(DateTime.parse(updatedAt))) {
      return;
    }
    final content = item['content'];
    if (content is! Map) {
      throw const FormatException('Item content must be an object.');
    }
    database.connection.execute(
      '''
      INSERT INTO learning_items (
        id, type, level, lesson, topic, learned, source_ref, content_json,
        created_at, updated_at, deleted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        type = excluded.type,
        level = excluded.level,
        lesson = excluded.lesson,
        topic = excluded.topic,
        learned = excluded.learned,
        source_ref = excluded.source_ref,
        content_json = excluded.content_json,
        updated_at = excluded.updated_at,
        deleted_at = excluded.deleted_at
      ''',
      <Object?>[
        id,
        _string(item, 'type'),
        _string(item, 'level'),
        _string(item, 'lesson'),
        _string(item, 'topic'),
        _bool(item, 'learned') ? 1 : 0,
        _string(item, 'sourceRef'),
        jsonEncode(content),
        _dateString(item, 'createdAt'),
        updatedAt,
        _nullableDateString(item, 'deletedAt'),
      ],
    );
  }

  void _mergeAttempt(Map<String, Object?> attempt) {
    database.connection.execute(
      '''
      INSERT OR IGNORE INTO practice_attempts (
        id, item_id, session_id, answer_text, correct, attempted_at
      ) VALUES (?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        _string(attempt, 'id'),
        _string(attempt, 'itemId'),
        _string(attempt, 'sessionId'),
        _string(attempt, 'answerText'),
        _bool(attempt, 'correct') ? 1 : 0,
        _dateString(attempt, 'attemptedAt'),
      ],
    );
  }

  void _mergeSession(Map<String, Object?> session) {
    final id = _string(session, 'id');
    final localDate = _string(session, 'localDate');
    final slotValue = session['slot'];
    final slot = slotValue == null ? null : _integer(session, 'slot');
    final existing = slot == null
        ? database.connection.select(
            'SELECT id FROM daily_sessions WHERE id = ?',
            <Object?>[id],
          )
        : database.connection.select(
            'SELECT id FROM daily_sessions WHERE local_date = ? AND slot = ?',
            <Object?>[localDate, slot],
          );
    final targetId = existing.isEmpty ? id : existing.single['id'] as String;
    final queue = session['queueItemIds'];
    if (queue is! List || queue.any((value) => value is! String)) {
      throw const FormatException('Session queue must be a string array.');
    }
    database.connection.execute(
      '''
      INSERT INTO daily_sessions (
        id, local_date, slot, kind, status, target_answers, answered_count,
        queue_json, last_item_id, created_at, updated_at, completed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        kind = excluded.kind,
        status = excluded.status,
        target_answers = excluded.target_answers,
        answered_count = excluded.answered_count,
        queue_json = excluded.queue_json,
        last_item_id = excluded.last_item_id,
        updated_at = excluded.updated_at,
        completed_at = excluded.completed_at
      ''',
      <Object?>[
        targetId,
        localDate,
        slot,
        session['kind'] is String ? session['kind'] as String : 'vocabulary',
        _string(session, 'status'),
        _integer(session, 'targetAnswers'),
        _integer(session, 'answeredCount'),
        jsonEncode(queue),
        session['lastItemId'] as String?,
        _dateString(session, 'createdAt'),
        _dateString(session, 'updatedAt'),
        _nullableDateString(session, 'completedAt'),
      ],
    );
  }

  void _mergeGrammarProgress(Map<String, Object?> progress) {
    final topicId = _string(progress, 'topicId');
    final updatedAt = _dateString(progress, 'updatedAt');
    final existing = database.connection.select(
      'SELECT updated_at FROM grammar_topic_progress WHERE topic_id = ?',
      <Object?>[topicId],
    );
    if (existing.isNotEmpty &&
        DateTime.parse(existing.single['updated_at'] as String)
            .isAfter(DateTime.parse(updatedAt))) {
      return;
    }
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
        _bool(progress, 'learned') ? 1 : 0,
        updatedAt,
      ],
    );
  }

  void _mergeGrammarAttempt(Map<String, Object?> attempt) {
    database.connection.execute(
      '''
      INSERT OR IGNORE INTO grammar_attempts (
        id, topic_id, exercise_id, session_id, answer_text, correct,
        attempted_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        _string(attempt, 'id'),
        _string(attempt, 'topicId'),
        _string(attempt, 'exerciseId'),
        _string(attempt, 'sessionId'),
        _string(attempt, 'answerText'),
        _bool(attempt, 'correct') ? 1 : 0,
        _dateString(attempt, 'attemptedAt'),
      ],
    );
  }

  String? _readSetting(String key) {
    final rows = database.connection.select(
      'SELECT value FROM app_settings WHERE key = ?',
      <Object?>[key],
    );
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  void _writeSetting(String key, String value) {
    database.connection.execute(
      '''
      INSERT INTO app_settings (key, value) VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      <Object?>[key, value],
    );
  }

  static Map<String, Object?> _itemToJson(dynamic row) => <String, Object?>{
        'id': row['id'] as String,
        'type': row['type'] as String,
        'level': row['level'] as String,
        'lesson': row['lesson'] as String,
        'topic': row['topic'] as String,
        'learned': (row['learned'] as int) == 1,
        'sourceRef': row['source_ref'] as String,
        'content': jsonDecode(row['content_json'] as String) as Object?,
        'createdAt': row['created_at'] as String,
        'updatedAt': row['updated_at'] as String,
        'deletedAt': row['deleted_at'] as String?,
      };

  static Map<String, Object?> _attemptToJson(dynamic row) => <String, Object?>{
        'id': row['id'] as String,
        'itemId': row['item_id'] as String,
        'sessionId': row['session_id'] as String,
        'answerText': row['answer_text'] as String,
        'correct': (row['correct'] as int) == 1,
        'attemptedAt': row['attempted_at'] as String,
      };

  static Map<String, Object?> _sessionToJson(dynamic row) => <String, Object?>{
        'id': row['id'] as String,
        'localDate': row['local_date'] as String,
        'slot': row['slot'] as int?,
        'kind': row['kind'] as String,
        'status': row['status'] as String,
        'targetAnswers': row['target_answers'] as int,
        'answeredCount': row['answered_count'] as int,
        'queueItemIds': jsonDecode(row['queue_json'] as String) as Object?,
        'lastItemId': row['last_item_id'] as String?,
        'createdAt': row['created_at'] as String,
        'updatedAt': row['updated_at'] as String,
        'completedAt': row['completed_at'] as String?,
      };

  static Map<String, Object?> _grammarProgressToJson(dynamic row) =>
      <String, Object?>{
        'topicId': row['topic_id'] as String,
        'learned': (row['learned'] as int) == 1,
        'updatedAt': row['updated_at'] as String,
      };

  static Map<String, Object?> _grammarAttemptToJson(dynamic row) =>
      <String, Object?>{
        'id': row['id'] as String,
        'topicId': row['topic_id'] as String,
        'exerciseId': row['exercise_id'] as String,
        'sessionId': row['session_id'] as String,
        'answerText': row['answer_text'] as String,
        'correct': (row['correct'] as int) == 1,
        'attemptedAt': row['attempted_at'] as String,
      };

  static List<Map<String, Object?>> _objectList(Object? value, String name) {
    if (value is! List) throw FormatException('$name must be an array.');
    return value.map((entry) {
      if (entry is! Map) {
        throw FormatException('$name entry must be an object.');
      }
      return entry.map(
        (key, item) => MapEntry(key.toString(), item as Object?),
      );
    }).toList(growable: false);
  }

  static String _string(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static int _integer(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static bool _bool(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! bool) throw FormatException('$key must be a boolean.');
    return value;
  }

  static String _dateString(Map<String, Object?> map, String key) {
    final value = _string(map, key);
    if (DateTime.tryParse(value) == null) {
      throw FormatException('$key must be a date.');
    }
    return value;
  }

  static String? _nullableDateString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String || DateTime.tryParse(value) == null) {
      throw FormatException('$key must be a nullable date.');
    }
    return value;
  }
}
