import '../daily_session.dart';
import '../practice.dart';

abstract interface class DailySessionRepository {
  Future<List<DailySession>> ensureDay({
    required String localDate,
    required DateTime now,
  });

  Future<DailySession?> findById(String id);

  Future<DailySession> createExtra({
    required String localDate,
    required DateTime now,
  });

  Future<DailySession> start({
    required String id,
    required List<String> queueItemIds,
    required DateTime now,
  });

  Future<DailySession> recordAnswer({
    required PracticeAttempt attempt,
    required List<String> remainingQueueItemIds,
    required DateTime now,
  });
}
