import '../../domain/app_language.dart';
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
}
