import '../practice.dart';

abstract interface class PracticeRepository {
  Future<void> saveAttempt(PracticeAttempt attempt);

  Future<PracticeSummary> summary();

  Future<List<ItemPracticeSummary>> problemItems({int limit = 20});
}
