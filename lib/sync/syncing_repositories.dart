import '../domain/daily_session.dart';
import '../domain/learning_item.dart';
import '../domain/practice.dart';
import '../domain/repositories/daily_session_repository.dart';
import '../domain/repositories/learning_item_repository.dart';
import '../domain/repositories/practice_repository.dart';

final class SyncingLearningItemRepository implements LearningItemRepository {
  const SyncingLearningItemRepository(this._delegate, this._onChanged);

  final LearningItemRepository _delegate;
  final void Function() _onChanged;

  @override
  Future<void> save(LearningItem item) async {
    await _delegate.save(item);
    _onChanged();
  }

  @override
  Future<void> saveAll(List<LearningItem> items) async {
    await _delegate.saveAll(items);
    if (items.isNotEmpty) _onChanged();
  }

  @override
  Future<LearningItem?> findById(String id) => _delegate.findById(id);

  @override
  Future<List<LearningItem>> findActive() => _delegate.findActive();

  @override
  Future<bool> softDelete(
      {required String id, required DateTime deletedAt}) async {
    final changed = await _delegate.softDelete(id: id, deletedAt: deletedAt);
    if (changed) _onChanged();
    return changed;
  }

  @override
  Future<bool> restore(
      {required String id, required DateTime restoredAt}) async {
    final changed = await _delegate.restore(id: id, restoredAt: restoredAt);
    if (changed) _onChanged();
    return changed;
  }
}

final class SyncingDailySessionRepository implements DailySessionRepository {
  SyncingDailySessionRepository(this._delegate, this._onChanged);

  final DailySessionRepository _delegate;
  final void Function() _onChanged;
  final Set<String> _ensuredDates = <String>{};

  @override
  Future<List<DailySession>> ensureDay({
    required String localDate,
    required DateTime now,
  }) async {
    final sessions = await _delegate.ensureDay(localDate: localDate, now: now);
    if (_ensuredDates.add(localDate)) _onChanged();
    return sessions;
  }

  @override
  Future<DailySession?> findById(String id) => _delegate.findById(id);

  @override
  Future<DailySession> createExtra({
    required String localDate,
    required DateTime now,
  }) async {
    final session = await _delegate.createExtra(localDate: localDate, now: now);
    _onChanged();
    return session;
  }

  @override
  Future<DailySession> start({
    required String id,
    required List<String> queueItemIds,
    required DateTime now,
  }) async {
    final session = await _delegate.start(
      id: id,
      queueItemIds: queueItemIds,
      now: now,
    );
    _onChanged();
    return session;
  }

  @override
  Future<DailySession> recordAnswer({
    required PracticeAttempt attempt,
    required List<String> remainingQueueItemIds,
    required DateTime now,
  }) async {
    final session = await _delegate.recordAnswer(
      attempt: attempt,
      remainingQueueItemIds: remainingQueueItemIds,
      now: now,
    );
    _onChanged();
    return session;
  }
}

final class SyncingPracticeRepository implements PracticeRepository {
  const SyncingPracticeRepository(this._delegate, this._onChanged);

  final PracticeRepository _delegate;
  final void Function() _onChanged;

  @override
  Future<void> saveAttempt(PracticeAttempt attempt) async {
    await _delegate.saveAttempt(attempt);
    _onChanged();
  }

  @override
  Future<List<ItemPracticeSummary>> problemItems({int limit = 20}) =>
      _delegate.problemItems(limit: limit);

  @override
  Future<Map<String, List<bool>>> recentOutcomes({int limitPerItem = 10}) =>
      _delegate.recentOutcomes(limitPerItem: limitPerItem);

  @override
  Future<PracticeSummary> summary() => _delegate.summary();

  @override
  Future<PracticeSummary> summaryForItem(String itemId) =>
      _delegate.summaryForItem(itemId);
}
