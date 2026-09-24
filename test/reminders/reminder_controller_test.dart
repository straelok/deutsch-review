import 'package:deutsch_review/domain/daily_session.dart';
import 'package:deutsch_review/domain/grammar.dart';
import 'package:deutsch_review/domain/practice.dart';
import 'package:deutsch_review/domain/repositories/daily_session_repository.dart';
import 'package:deutsch_review/reminders/reminder_controller.dart';
import 'package:deutsch_review/reminders/reminder_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schedules reminders and skips today after five sessions', () async {
    final sessions = _FakeSessions();
    final gateway = _FakeGateway();
    final controller = ReminderController(
      sessions: sessions,
      gateway: gateway,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    expect(gateway.skipToday, isFalse);

    sessions.completed = 5;
    await controller.refresh(force: true);
    expect(gateway.skipToday, isTrue);
  });

  test('notification tap requests the today page', () async {
    final gateway = _FakeGateway();
    final controller = ReminderController(
      sessions: _FakeSessions(),
      gateway: gateway,
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    final revision = controller.openTodayRevision;
    gateway.openToday();

    expect(controller.openTodayRevision, revision + 1);
  });
}

final class _FakeGateway implements ReminderGateway {
  late void Function() openToday;
  bool skipToday = false;

  @override
  bool get isSupported => true;

  @override
  Future<bool> initialize(void Function() onOpenToday) async {
    openToday = onOpenToday;
    return false;
  }

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> replaceSchedule({
    required DateTime now,
    required bool skipToday,
    required ReminderCopy copy,
  }) async {
    this.skipToday = skipToday;
  }
}

final class _FakeSessions implements DailySessionRepository {
  int completed = 0;

  @override
  Future<List<DailySession>> ensureDay({
    required String localDate,
    required DateTime now,
    bool includeGrammar = false,
  }) async {
    return List.generate(
      5,
      (index) => DailySession(
        id: '$localDate-${index + 1}',
        localDate: localDate,
        slot: index + 1,
        kind: DailySessionKind.vocabulary,
        status: index < completed
            ? DailySessionStatus.completed
            : DailySessionStatus.planned,
        targetAnswers: 20,
        answeredCount: index < completed ? 20 : 0,
        queueItemIds: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<DailySession> createExtra({
    required String localDate,
    required DateTime now,
  }) =>
      throw UnimplementedError();

  @override
  Future<DailySession?> findById(String id) => throw UnimplementedError();

  @override
  Future<DailySession> recordAnswer({
    required PracticeAttempt attempt,
    required List<String> remainingQueueItemIds,
    required DateTime now,
  }) =>
      throw UnimplementedError();

  @override
  Future<DailySession> recordGrammarTask({
    required String sessionId,
    required List<GrammarAttempt> attempts,
    required List<String> remainingQueueItemIds,
    required String lastExerciseId,
    required DateTime now,
  }) =>
      throw UnimplementedError();

  @override
  Future<DailySession> start({
    required String id,
    required List<String> queueItemIds,
    required DateTime now,
  }) =>
      throw UnimplementedError();
}
