import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/app_database_path.dart';
import 'data/repositories/sqlite_learning_item_repository.dart';
import 'data/repositories/sqlite_daily_session_repository.dart';
import 'data/repositories/sqlite_practice_repository.dart';
import 'data/repositories/sqlite_settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = AppDatabase.open(await applicationDatabasePath());
    runApp(
      DeutschReviewApp(
        learningItems: SqliteLearningItemRepository(database),
        sessions: SqliteDailySessionRepository(database),
        settings: SqliteSettingsRepository(database),
        practice: SqlitePracticeRepository(database),
        onDispose: database.close,
      ),
    );
  } catch (error) {
    runApp(DatabaseErrorApp(message: error.toString()));
  }
}
