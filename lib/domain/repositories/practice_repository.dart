import '../practice.dart';

abstract interface class PracticeRepository {
  Future<void> saveAttempt(PracticeAttempt attempt);

  Future<PracticeSummary> summary();

  Future<PracticeSummary> summaryForItem(String itemId);

  Future<Map<String, List<bool>>> recentOutcomes({int limitPerItem = 10});

  Future<List<ItemPracticeSummary>> problemItems({int limit = 20});
}
