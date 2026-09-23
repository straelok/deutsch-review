import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/app_database_path.dart';
import 'data/repositories/sqlite_learning_item_repository.dart';
import 'data/repositories/sqlite_daily_session_repository.dart';
import 'data/repositories/sqlite_practice_repository.dart';
import 'data/repositories/sqlite_settings_repository.dart';
import 'sync/sqlite_sync_store.dart';
import 'sync/supabase_sync_gateway.dart';
import 'sync/sync_controller.dart';
import 'sync/sync_models.dart';
import 'sync/syncing_repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = AppDatabase.open(await applicationDatabasePath());
    final configuration = SyncConfiguration.fromEnvironment();
    final syncController = SyncController(
      localStore: SqliteSyncStore(database),
      gateway: configuration == null
          ? null
          : SupabaseSyncGateway(
              url: configuration.url,
              publishableKey: configuration.publishableKey,
            ),
    );
    await syncController.initialize();
    final learningItems = SyncingLearningItemRepository(
      SqliteLearningItemRepository(database),
      syncController.scheduleSync,
    );
    final sessions = SyncingDailySessionRepository(
      SqliteDailySessionRepository(database),
      syncController.scheduleSync,
    );
    final practice = SyncingPracticeRepository(
      SqlitePracticeRepository(database),
      syncController.scheduleSync,
    );
    runApp(
      DeutschReviewApp(
        learningItems: learningItems,
        sessions: sessions,
        settings: SqliteSettingsRepository(database),
        practice: practice,
        syncController: syncController,
        onDispose: () {
          syncController.dispose();
          database.close();
        },
      ),
    );
  } catch (error) {
    runApp(DatabaseErrorApp(message: error.toString()));
  }
}
