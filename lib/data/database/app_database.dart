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
    return _initialize(sqlite3.open(path));
  }

  static AppDatabase inMemory() {
    return _initialize(sqlite3.openInMemory());
  }

  static AppDatabase _initialize(Database connection) {
    try {
      connection
        ..execute('PRAGMA foreign_keys = ON')
        ..execute('PRAGMA busy_timeout = 5000')
        ..execute('PRAGMA journal_mode = WAL');
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
    final row = connection.select('PRAGMA user_version').single;
    final version = row.values.single as int;

    if (version > currentSchemaVersion) {
      throw UnsupportedSchemaVersion(version, currentSchemaVersion);
    }
    if (version == currentSchemaVersion) {
      return;
    }
    if (version != 0) {
      throw UnsupportedSchemaVersion(version, currentSchemaVersion);
    }

    connection.execute('BEGIN IMMEDIATE');
    try {
      connection.execute(migrationFrom0To1);
      connection.execute('PRAGMA user_version = $currentSchemaVersion');
      connection.execute('COMMIT');
    } catch (_) {
      connection.execute('ROLLBACK');
      rethrow;
    }
  }
}
