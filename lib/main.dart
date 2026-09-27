import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'content/content_bundle.dart';
import 'content/content_controller.dart';
import 'content/content_gateway.dart';
import 'content/content_store.dart';
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
    final databasePath = await applicationDatabasePath();
    final database = AppDatabase.open(databasePath);
    final bundledContent = await loadBundledContent(rootBundle);
    final configuration = SyncConfiguration.fromEnvironment();
    final contentController = ContentController(
      bundled: bundledContent,
      store: ContentStore(
        Directory(
          '${File(databasePath).parent.path}${Platform.pathSeparator}content',
        ),
      ),
      gateway: configuration == null
          ? null
          : HttpContentGateway(supabaseUrl: configuration.url),
    );
    await contentController.initialize();
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
    final localSessions = SqliteDailySessionRepository(
      database,
      contentVersion: () => contentController.catalog.contentVersion,
    );
    await contentController.pruneVersions(
      localSessions.unfinishedContentVersions(),
    );
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
              return contentController.catalog
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
    final sessions = SyncingDailySessionRepository(localSessions, () {
      syncController.scheduleSync();
      reminders?.refresh();
    });
    final practice = SyncingPracticeRepository(
      SqlitePracticeRepository(database),
      syncController.scheduleSync,
    );
    final settings = SqliteSettingsRepository(database);
    final initialLanguage = await settings.readLanguage();
    runApp(
      DeutschReviewApp(
        learningItems: learningItems,
        sessions: sessions,
        settings: settings,
        practice: practice,
        grammar: grammar,
        grammarCatalog: contentController.catalog,
        contentController: contentController,
        syncController: syncController,
        reminders: reminders,
        initialLanguage: initialLanguage,
        onDispose: () {
          reminders?.dispose();
          syncController.dispose();
          contentController.dispose();
          database.close();
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (reminders != null) unawaited(reminders.initialize());
      unawaited(contentController.checkOnLaunch());
    });
  } catch (error) {
    runApp(DatabaseErrorApp(message: error.toString()));
  }
}
