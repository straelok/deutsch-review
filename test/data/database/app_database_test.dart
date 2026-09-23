import 'dart:io';

import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/database/schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('migrates an empty database to schema version 1', () {
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
        'review_events',
        'review_schedules',
      ]),
    );
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
