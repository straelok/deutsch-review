import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/learning_item.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../database/app_database.dart';

final class SqliteLearningItemRepository implements LearningItemRepository {
  const SqliteLearningItemRepository(this.database);

  final AppDatabase database;

  @override
  Future<void> save(LearningItem item) async {
    _save(item);
  }

  @override
  Future<void> saveAll(List<LearningItem> items) async {
    database.connection.execute('BEGIN IMMEDIATE');
    try {
      for (final item in items) {
        _save(item);
      }
      database.connection.execute('COMMIT');
    } catch (_) {
      database.connection.execute('ROLLBACK');
      rethrow;
    }
  }

  void _save(LearningItem item) {
    final statement = database.connection.prepare('''
      INSERT INTO learning_items (
        id,
        type,
        level,
        lesson,
        topic,
        learned,
        source_ref,
        content_json,
        created_at,
        updated_at,
        deleted_at
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
    ''');
    try {
      statement.execute(<Object?>[
        item.id,
        item.type.wireName,
        item.level,
        item.lesson,
        item.topic,
        item.learned ? 1 : 0,
        item.sourceRef,
        jsonEncode(item.content),
        _encodeDateTime(item.createdAt),
        _encodeDateTime(item.updatedAt),
        item.deletedAt == null ? null : _encodeDateTime(item.deletedAt!),
      ]);
    } finally {
      statement.close();
    }
  }

  @override
  Future<LearningItem?> findById(String id) async {
    final rows = database.connection.select(
      'SELECT * FROM learning_items WHERE id = ?',
      <Object?>[id],
    );
    return rows.isEmpty ? null : _mapRow(rows.single);
  }

  @override
  Future<List<LearningItem>> findActive() async {
    final rows = database.connection.select('''
      SELECT *
      FROM learning_items
      WHERE deleted_at IS NULL
      ORDER BY created_at DESC, id ASC
    ''');
    return rows.map(_mapRow).toList(growable: false);
  }

  @override
  Future<bool> softDelete({
    required String id,
    required DateTime deletedAt,
  }) async {
    final timestamp = _encodeDateTime(deletedAt);
    database.connection.execute(
      '''
      UPDATE learning_items
      SET deleted_at = ?, updated_at = ?
      WHERE id = ? AND deleted_at IS NULL
      ''',
      <Object?>[timestamp, timestamp, id],
    );
    return database.connection.updatedRows > 0;
  }

  @override
  Future<bool> restore({
    required String id,
    required DateTime restoredAt,
  }) async {
    database.connection.execute(
      '''
      UPDATE learning_items
      SET deleted_at = NULL, updated_at = ?
      WHERE id = ? AND deleted_at IS NOT NULL
      ''',
      <Object?>[_encodeDateTime(restoredAt), id],
    );
    return database.connection.updatedRows > 0;
  }

  static LearningItem _mapRow(Row row) {
    final decodedContent = jsonDecode(row['content_json'] as String);
    if (decodedContent is! Map<String, Object?>) {
      throw const FormatException('content_json must contain a JSON object');
    }

    return LearningItem(
      id: row['id'] as String,
      type: LearningItemType.fromWireName(row['type'] as String),
      level: row['level'] as String,
      lesson: row['lesson'] as String,
      topic: row['topic'] as String,
      learned: (row['learned'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String).toUtc(),
      updatedAt: DateTime.parse(row['updated_at'] as String).toUtc(),
      deletedAt: switch (row['deleted_at']) {
        final String value => DateTime.parse(value).toUtc(),
        _ => null,
      },
      sourceRef: row['source_ref'] as String,
      content: decodedContent,
    );
  }

  static String _encodeDateTime(DateTime value) {
    return value.toUtc().toIso8601String();
  }
}
