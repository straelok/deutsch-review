import '../grammar.dart';

abstract interface class GrammarRepository {
  Future<Map<String, GrammarTopicProgress>> progress();

  Future<void> setLearned({
    required String topicId,
    required bool learned,
    required DateTime now,
  });

  Future<GrammarSummary> summary(String topicId);

  Future<Map<String, List<bool>>> recentOutcomes({int limitPerTopic = 10});
}
