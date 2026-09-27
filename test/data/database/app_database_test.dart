import 'dart:io';

import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/database/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates an empty database to the current schema', () {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    expect(database.schemaVersion, currentSchemaVersion);
    expect(database.integrityCheck(), <String>['ok']);
    expect(database.foreignKeyCheck(), isEmpty);

    final tables = database.connection
        .select(
          "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
        )
        .map((row) => row['name'])
        .toList();
    expect(
      tables,
      containsAll(<String>[
        'learning_items',
        'app_settings',
        'daily_sessions',
        'grammar_attempts',
        'grammar_topic_progress',
        'practice_attempts',
      ]),
    );
    expect(tables, isNot(contains('review_events')));
    expect(tables, isNot(contains('review_schedules')));
  });

  test('backs up version 1 before migrating it to the current version', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}existing.sqlite';
    final oldDatabase = sqlite3.open(path);
    oldDatabase.execute(migrationFrom0To1);
    oldDatabase.execute('PRAGMA user_version = 1');
    oldDatabase.execute('''
      INSERT INTO learning_items (
        id, type, level, lesson, topic, learned, source_ref, content_json,
        created_at, updated_at, deleted_at
      ) VALUES (
        'old-item', 'word', 'A1.1', '1', 'Test', 1, 'DAA',
        '{"german":"lernen","translation_ru":"учить"}',
        '2026-09-23T10:00:00.000Z', '2026-09-23T10:00:00.000Z', NULL
      )
    ''');
    oldDatabase.close();

    final migrated = AppDatabase.open(path);
    addTearDown(migrated.close);

    expect(migrated.schemaVersion, currentSchemaVersion);
    expect(
      migrated.connection.select('SELECT id FROM learning_items').single['id'],
      'old-item',
    );
    final backups = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('existing.sqlite.backup-v1-'))
        .toList();
    expect(backups, hasLength(1));
    final backup = sqlite3.open(backups.single.path);
    addTearDown(backup.close);
    expect(backup.select('PRAGMA user_version').single.values.single, 1);
    expect(
      backup.select('SELECT id FROM learning_items').single['id'],
      'old-item',
    );
  });

  test('backs up version 2 before adding daily sessions', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}version2.sqlite';
    final oldDatabase = sqlite3.open(path);
    oldDatabase.execute(migrationFrom0To1);
    oldDatabase.execute(migrationFrom1To2);
    oldDatabase.execute('PRAGMA user_version = 2');
    oldDatabase.close();

    final migrated = AppDatabase.open(path);
    addTearDown(migrated.close);

    expect(migrated.schemaVersion, currentSchemaVersion);
    final backups = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('version2.sqlite.backup-v2-'))
        .toList();
    expect(backups, hasLength(1));
    final backup = sqlite3.open(backups.single.path);
    addTearDown(backup.close);
    expect(backup.select('PRAGMA user_version').single.values.single, 2);
    expect(
      backup.select(
        "SELECT name FROM sqlite_master WHERE name = 'review_events'",
      ),
      isNotEmpty,
    );
  });

  test('migrates version 3 sessions to the current directional schema', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}version3.sqlite';
    final oldDatabase = sqlite3.open(path);
    oldDatabase.execute(migrationFrom0To1);
    oldDatabase.execute(migrationFrom1To2);
    oldDatabase.execute(migrationFrom2To3);
    oldDatabase.execute('PRAGMA user_version = 3');
    oldDatabase.execute('''
      INSERT INTO daily_sessions (
        id, local_date, slot, status, target_answers, answered_count,
        queue_json, last_item_id, created_at, updated_at, completed_at
      ) VALUES (
        'session-1', '2026-09-24', 1, 'planned', 20, 0, '[]', NULL,
        '2026-09-24T10:00:00.000Z', '2026-09-24T10:00:00.000Z', NULL
      )
    ''');
    oldDatabase.close();

    final migrated = AppDatabase.open(path);
    addTearDown(migrated.close);

    expect(migrated.schemaVersion, currentSchemaVersion);
    final session = migrated.connection
        .select("SELECT * FROM daily_sessions WHERE id = 'session-1'")
        .single;
    expect(session['kind'], 'vocabulary_to_german');
    expect(migrated.integrityCheck(), ['ok']);
    expect(migrated.foreignKeyCheck(), isEmpty);
    expect(
      directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('version3.sqlite.backup-v3-')),
      hasLength(1),
    );
  });

  test('moves version 4 grammar slots without losing progress', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}version4.sqlite';
    final oldDatabase = sqlite3.open(path);
    oldDatabase
      ..execute(migrationFrom0To1)
      ..execute(migrationFrom1To2)
      ..execute(migrationFrom2To3)
      ..execute(migrationFrom3To4)
      ..execute('PRAGMA user_version = 4')
      ..execute('''
        INSERT INTO daily_sessions (
          id, local_date, slot, kind, status, target_answers, answered_count,
          queue_json, last_item_id, created_at, updated_at, completed_at
        ) VALUES
          ('word-session', '2026-09-25', 4, 'vocabulary', 'planned', 20, 0,
           '[]', NULL, '2026-09-25T10:00:00.000Z',
           '2026-09-25T10:00:00.000Z', NULL),
          ('grammar-session', '2026-09-25', 6, 'grammar', 'in_progress', 10, 3,
           '["exercise-1"]', 'exercise-0', '2026-09-25T10:00:00.000Z',
           '2026-09-25T10:10:00.000Z', NULL)
      ''')
      ..close();

    final migrated = AppDatabase.open(path);
    addTearDown(migrated.close);
    final word = migrated.connection
        .select("SELECT * FROM daily_sessions WHERE id = 'word-session'")
        .single;
    final grammar = migrated.connection
        .select("SELECT * FROM daily_sessions WHERE id = 'grammar-session'")
        .single;

    expect(word['kind'], 'vocabulary_to_russian');
    expect(word['slot'], 4);
    expect(grammar['kind'], 'grammar');
    expect(grammar['slot'], 9);
    expect(grammar['answered_count'], 3);
    expect(migrated.integrityCheck(), ['ok']);
  });

  test('moves version 5 grammar and expands planned number lessons', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}version5.sqlite';
    final oldDatabase = sqlite3.open(path);
    oldDatabase
      ..execute(migrationFrom0To1)
      ..execute(migrationFrom1To2)
      ..execute(migrationFrom2To3)
      ..execute(migrationFrom3To4)
      ..execute(migrationFrom4To5)
      ..execute('PRAGMA user_version = 5')
      ..execute('''
        INSERT INTO daily_sessions (
          id, local_date, slot, kind, status, target_answers, answered_count,
          queue_json, last_item_id, created_at, updated_at, completed_at
        ) VALUES
          ('numbers', '2026-09-26', 7, 'numbers', 'planned', 10, 0,
           '[]', NULL, '2026-09-26T10:00:00.000Z',
           '2026-09-26T10:00:00.000Z', NULL),
          ('grammar', '2026-09-26', 8, 'grammar', 'in_progress', 10, 3,
           '["exercise-1"]', 'exercise-0', '2026-09-26T10:00:00.000Z',
           '2026-09-26T10:10:00.000Z', NULL)
      ''')
      ..close();

    final migrated = AppDatabase.open(path);
    addTearDown(migrated.close);
    final numbers = migrated.connection
        .select("SELECT * FROM daily_sessions WHERE id = 'numbers'")
        .single;
    final grammar = migrated.connection
        .select("SELECT * FROM daily_sessions WHERE id = 'grammar'")
        .single;

    expect(numbers['slot'], 7);
    expect(numbers['target_answers'], 20);
    expect(grammar['slot'], 9);
    expect(grammar['answered_count'], 3);
    expect(migrated.integrityCheck(), ['ok']);
  });

  test('rejects a database created by a newer application version', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}future.sqlite';
    final futureDatabase = sqlite3.open(path);
    futureDatabase.execute(
      'PRAGMA user_version = ${currentSchemaVersion + 1}',
    );
    futureDatabase.close();

    expect(
      () => AppDatabase.open(path),
      throwsA(isA<UnsupportedSchemaVersion>()),
    );
  });

  test('keeps schema version after closing and reopening a file', () {
    final directory = Directory.systemTemp.createTempSync('deutsch_review_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}app.sqlite';

    AppDatabase.open(path).close();
    final reopened = AppDatabase.open(path);
    addTearDown(reopened.close);

    expect(reopened.schemaVersion, currentSchemaVersion);
    expect(reopened.integrityCheck(), <String>['ok']);
  });
}
