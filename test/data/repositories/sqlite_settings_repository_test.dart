import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_settings_repository.dart';
import 'package:deutsch_review/domain/app_language.dart';
import 'package:deutsch_review/domain/app_settings.dart';
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

  test('persists learning plan and reminder settings', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteSettingsRepository(database);

    const settings = AppSettings(
      includeImportantLessons: false,
      toGermanLessons: 1,
      toGermanTasks: 12,
      problemWordMaxWeight: 37,
      reminderMinutes: [540, 1080],
    );
    await repository.saveAppSettings(settings);

    final saved = await repository.readAppSettings();
    expect(saved.includeImportantLessons, isFalse);
    expect(saved.toGermanLessons, 1);
    expect(saved.toGermanTasks, 12);
    expect(saved.problemWordMaxWeight, 37);
    expect(saved.reminderMinutes, [540, 1080]);
  });

  test('uses the previous weight by default and bounds imported values', () {
    expect(AppSettings.fromJson(const {}).problemWordMaxWeight, 10);
    expect(
      AppSettings.fromJson(
        const {'problemWordMaxWeight': 0},
      ).problemWordMaxWeight,
      1,
    );
    expect(
      AppSettings.fromJson(
        const {'problemWordMaxWeight': 2000000},
      ).problemWordMaxWeight,
      1000000,
    );
  });
}
