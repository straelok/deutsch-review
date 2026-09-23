import '../practice.dart';

abstract interface class PracticeRepository {
  Future<void> saveAttempt(PracticeAttempt attempt);

  Future<PracticeSummary> summary();

  Future<PracticeSummary> summaryForItem(String itemId);

  Future<List<ItemPracticeSummary>> problemItems({int limit = 20});
}
