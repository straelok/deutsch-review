import 'learning_item.dart';

final class PracticeAttempt {
  const PracticeAttempt({
    required this.id,
    required this.itemId,
    required this.sessionId,
    required this.answerText,
    required this.correct,
    required this.attemptedAt,
  });

  final String id;
  final String itemId;
  final String sessionId;
  final String answerText;
  final bool correct;
  final DateTime attemptedAt;
}

final class PracticeSummary {
  const PracticeSummary({
    required this.attempts,
    required this.correct,
  });

  final int attempts;
  final int correct;

  int get errors => attempts - correct;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}

final class ItemPracticeSummary {
  const ItemPracticeSummary({
    required this.item,
    required this.attempts,
    required this.correct,
  });

  final LearningItem item;
  final int attempts;
  final int correct;

  int get errors => attempts - correct;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}
