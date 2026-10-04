import 'dart:convert';

import '../../domain/app_language.dart';
import '../../domain/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../database/app_database.dart';

final class SqliteSettingsRepository implements SettingsRepository {
  const SqliteSettingsRepository(this.database);

  final AppDatabase database;

  @override
  Future<AppLanguage> readLanguage() async {
    final rows = database.connection.select(
      "SELECT value FROM app_settings WHERE key = 'language'",
    );
    return AppLanguage.fromCode(
      rows.isEmpty ? null : rows.single['value'] as String,
    );
  }

  @override
  Future<void> saveLanguage(AppLanguage language) async {
    database.connection.execute(
      '''
      INSERT INTO app_settings (key, value) VALUES ('language', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      <Object?>[language.code],
    );
  }

  @override
  Future<AppSettings> readAppSettings() async {
    final rows = database.connection.select(
      "SELECT value FROM app_settings WHERE key = 'app_settings'",
    );
    if (rows.isEmpty) return const AppSettings();
    try {
      final decoded = jsonDecode(rows.single['value'] as String);
      if (decoded is! Map) return const AppSettings();
      return AppSettings.fromJson(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on FormatException {
      return const AppSettings();
    }
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    database.connection.execute(
      '''
      INSERT INTO app_settings (key, value) VALUES ('app_settings', ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value
      ''',
      <Object?>[jsonEncode(settings.toJson())],
    );
  }
}
