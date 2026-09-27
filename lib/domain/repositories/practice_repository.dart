import '../practice.dart';

abstract interface class PracticeRepository {
  Future<void> saveAttempt(PracticeAttempt attempt);

  Future<PracticeSummary> summary();

  Future<Map<String, WordPracticeStatistics>> statisticsByItem({
    int recentLimit = 10,
  });

  Future<Map<String, List<bool>>> recentOutcomes({int limitPerItem = 10});

  Future<List<ItemPracticeSummary>> problemItems({int limit = 20});
}
