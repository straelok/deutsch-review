import '../learning_item.dart';

abstract interface class LearningItemRepository {
  Future<void> save(LearningItem item);

  Future<LearningItem?> findById(String id);

  Future<List<LearningItem>> findActive();

  Future<bool> softDelete({
    required String id,
    required DateTime deletedAt,
  });

  Future<bool> restore({
    required String id,
    required DateTime restoredAt,
  });
}
