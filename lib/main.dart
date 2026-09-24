import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'data/database/app_database.dart';
import 'data/database/app_database_path.dart';
import 'data/repositories/sqlite_learning_item_repository.dart';
import 'data/repositories/sqlite_grammar_repository.dart';
import 'data/repositories/sqlite_daily_session_repository.dart';
import 'data/repositories/sqlite_practice_repository.dart';
import 'data/repositories/sqlite_settings_repository.dart';
import 'reminders/android_reminder_gateway.dart';
import 'grammar/grammar_catalog.dart';
import 'reminders/reminder_controller.dart';
import 'sync/sqlite_sync_store.dart';
import 'sync/supabase_sync_gateway.dart';
import 'sync/sync_controller.dart';
import 'sync/sync_models.dart';
import 'sync/syncing_repositories.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final database = AppDatabase.open(await applicationDatabasePath());
    final grammarCatalog = await GrammarCatalog.load(rootBundle);
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
    final grammar = SyncingGrammarRepository(
      SqliteGrammarRepository(database),
      syncController.scheduleSync,
    );
    final localSessions = SqliteDailySessionRepository(database);
    final reminders = Platform.isAndroid
        ? ReminderController(
            sessions: localSessions,
            gateway: AndroidReminderGateway(),
            grammarAvailability: () async {
              final progress = await grammar.progress();
              final items = await learningItems.findActive();
              final lemmas = items
                  .where((item) => item.type.wireName == 'verb')
                  .map((item) => GrammarCatalog.normalizeLemma(
                        item.content['german'] as String? ?? '',
                      ))
                  .toSet();
              return grammarCatalog
                  .availableTopicIds(
                    learnedTopicIds: progress.values
                        .where((entry) => entry.learned)
                        .map((entry) => entry.topicId)
                        .toSet(),
                    activeLemmas: lemmas,
                  )
                  .isNotEmpty;
            },
          )
        : null;
    await reminders?.initialize();
    final sessions = SyncingDailySessionRepository(localSessions, () {
      syncController.scheduleSync();
      reminders?.refresh();
    });
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
        grammar: grammar,
        grammarCatalog: grammarCatalog,
        syncController: syncController,
        reminders: reminders,
        onDispose: () {
          reminders?.dispose();
          syncController.dispose();
          database.close();
        },
      ),
    );
  } catch (error) {
    runApp(DatabaseErrorApp(message: error.toString()));
  }
}
