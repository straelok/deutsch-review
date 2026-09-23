import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

final class UnsupportedSchemaVersion implements Exception {
  const UnsupportedSchemaVersion(this.found, this.supported);

  final int found;
  final int supported;

  @override
  String toString() {
    return 'Unsupported database schema version $found; '
        'maximum supported version is $supported.';
  }
}

final class AppDatabase {
  AppDatabase._(this.connection);

  final Database connection;

  static AppDatabase open(String path) {
    return _initialize(sqlite3.open(path), path: path);
  }

  static AppDatabase inMemory() {
    return _initialize(sqlite3.openInMemory());
  }

  static AppDatabase _initialize(Database connection, {String? path}) {
    try {
      connection
        ..execute('PRAGMA foreign_keys = ON')
        ..execute('PRAGMA busy_timeout = 5000')
        ..execute('PRAGMA journal_mode = WAL');
      final version = _readSchemaVersion(connection);
      if (path != null && version > 0 && version < currentSchemaVersion) {
        _createBackup(connection, path, version);
      }
      _migrate(connection);
      return AppDatabase._(connection);
    } catch (_) {
      connection.close();
      rethrow;
    }
  }

  int get schemaVersion {
    final row = connection.select('PRAGMA user_version').single;
    return row.values.single as int;
  }

  List<String> integrityCheck() {
    return connection
        .select('PRAGMA integrity_check')
        .map((row) => row.values.single as String)
        .toList(growable: false);
  }

  List<String> foreignKeyCheck() {
    return connection
        .select('PRAGMA foreign_key_check')
        .map((row) => row.values.join(':'))
        .toList(growable: false);
  }

  void close() => connection.close();

  static void _migrate(Database connection) {
    var version = _readSchemaVersion(connection);

    if (version > currentSchemaVersion) {
      throw UnsupportedSchemaVersion(version, currentSchemaVersion);
    }
    while (version < currentSchemaVersion) {
      final migration = switch (version) {
        0 => migrationFrom0To1,
        1 => migrationFrom1To2,
        _ => throw UnsupportedSchemaVersion(version, currentSchemaVersion),
      };
      _runMigration(connection, migration, version + 1);
      version += 1;
    }
  }

  static void _runMigration(
    Database connection,
    String migration,
    int targetVersion,
  ) {
    connection.execute('BEGIN IMMEDIATE');
    try {
      connection.execute(migration);
      connection.execute('PRAGMA user_version = $targetVersion');
      connection.execute('COMMIT');
    } catch (_) {
      connection.execute('ROLLBACK');
      rethrow;
    }
  }

  static int _readSchemaVersion(Database connection) {
    final row = connection.select('PRAGMA user_version').single;
    return row.values.single as int;
  }

  static void _createBackup(Database connection, String path, int version) {
    if (!File(path).existsSync()) return;
    connection.execute('PRAGMA wal_checkpoint(FULL)');
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final backupPath = '$path.backup-v$version-$stamp';
    connection.execute('VACUUM INTO ?', <Object?>[backupPath]);
  }
}
