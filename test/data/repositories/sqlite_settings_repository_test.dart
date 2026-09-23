import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_settings_repository.dart';
import 'package:deutsch_review/domain/app_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to German and persists the selected language', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteSettingsRepository(database);

    expect(await repository.readLanguage(), AppLanguage.german);
    await repository.saveLanguage(AppLanguage.russian);
    expect(await repository.readLanguage(), AppLanguage.russian);
  });
}
