import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_daily_session_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_grammar_repository.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/sync/sqlite_sync_store.dart';
import 'package:deutsch_review/sync/sync_controller.dart';
import 'package:deutsch_review/sync/sync_gateway.dart';
import 'package:deutsch_review/sync/sync_models.dart';
import 'package:deutsch_review/sync/syncing_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normalizes and validates nicknames', () {
    expect(normalizeNickname('  BiBa_24  '), 'biba_24');
    expect(isValidNickname('abc'), isTrue);
    expect(isValidNickname('A-B_123'), isTrue);
    expect(isValidNickname('ab'), isFalse);
    expect(isValidNickname('имя'), isFalse);
    expect(isValidNickname('has space'), isFalse);
  });

  test('merges all local data without duplicating required sessions', () async {
    final source = AppDatabase.inMemory();
    final target = AppDatabase.inMemory();
    addTearDown(source.close);
    addTearDown(target.close);
    final sourceItems = SqliteLearningItemRepository(source);
    final sourceSessions = SqliteDailySessionRepository(source);
    final targetSessions = SqliteDailySessionRepository(target);
    final now = DateTime.utc(2026, 9, 23, 10);

    await sourceItems.save(_word(now));
    await sourceItems.softDelete(
      id: 'word-1',
      deletedAt: now.add(const Duration(minutes: 2)),
    );
    await sourceSessions.ensureDay(localDate: '2026-09-23', now: now);
    await targetSessions.ensureDay(localDate: '2026-09-23', now: now);
    await SqliteGrammarRepository(source).setLearned(
      topicId: 'regular_present',
      learned: true,
      now: now,
    );

    final payload = SqliteSyncStore(source).buildPayload();
    SqliteSyncStore(target).mergePayload(payload);

    final item = await SqliteLearningItemRepository(target).findById('word-1');
    expect(item, isNotNull);
    expect(item!.deletedAt, isNotNull);
    final sessions = target.connection.select(
      "SELECT * FROM daily_sessions WHERE local_date = '2026-09-23'",
    );
    expect(sessions, hasLength(5));
    expect(target.integrityCheck(), <String>['ok']);
    expect(target.foreignKeyCheck(), isEmpty);
    expect(
      (await SqliteGrammarRepository(target).progress())['regular_present']
          ?.learned,
      isTrue,
    );
  });

  test('controller persists nickname and completes synchronization', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final gateway = _EchoGateway();
    final controller = SyncController(
      localStore: SqliteSyncStore(database),
      gateway: gateway,
      connectivityChanges: const Stream<List<ConnectivityResult>>.empty(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.connect('  Test_User '), isTrue);
    expect(controller.nickname, 'test_user');
    expect(controller.phase, SyncPhase.synced);
    expect(controller.lastSuccess, isNotNull);
    expect(gateway.calls, 1);
    expect(SqliteSyncStore(database).readNickname(), 'test_user');

    await controller.disconnect();
    expect(controller.nickname, isNull);
    expect(controller.phase, SyncPhase.disconnected);
  });

  test('ensuring the same day schedules synchronization only once', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    var changes = 0;
    final repository = SyncingDailySessionRepository(
      SqliteDailySessionRepository(database),
      () => changes++,
    );
    final now = DateTime.utc(2026, 9, 24, 8);

    await repository.ensureDay(localDate: '2026-09-24', now: now);
    await repository.ensureDay(localDate: '2026-09-24', now: now);

    expect(changes, 1);
  });
}

LearningItem _word(DateTime now) {
  return LearningItem(
    id: 'word-1',
    type: LearningItemType.word,
    level: '',
    lesson: '',
    topic: '',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: '',
    content: const {'german': 'lernen', 'translation_ru': 'учить'},
  );
}

final class _EchoGateway implements SyncGateway {
  int calls = 0;

  @override
  Future<Map<String, Object?>> synchronize({
    required String nickname,
    required Map<String, Object?> localPayload,
  }) async {
    calls++;
    return localPayload;
  }
}
