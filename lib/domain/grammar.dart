final class GrammarTopic {
  const GrammarTopic({
    required this.id,
    required this.order,
    required this.titleDe,
    required this.titleRu,
    required this.summaryDe,
    required this.summaryRu,
    required this.explanationDe,
    required this.explanationRu,
    required this.table,
    required this.trainable,
  });

  final String id;
  final int order;
  final String titleDe;
  final String titleRu;
  final String summaryDe;
  final String summaryRu;
  final List<String> explanationDe;
  final List<String> explanationRu;
  final List<List<String>> table;
  final bool trainable;
}

final class GrammarVerb {
  const GrammarVerb({
    required this.lemma,
    required this.topicId,
    required this.stem,
    required this.forms,
  });

  final String lemma;
  final String topicId;
  final String stem;
  final Map<String, String> forms;
}

final class GrammarExercise {
  const GrammarExercise({
    required this.id,
    required this.topicId,
    required this.lemma,
    required this.prompt,
    required this.answer,
    this.type = GrammarExerciseType.text,
    this.requiredItemType = 'verb',
    this.options = const [],
    this.instructionDe = '',
    this.instructionRu = '',
  });

  final String id;
  final String topicId;
  final String lemma;
  final String prompt;
  final String answer;
  final GrammarExerciseType type;
  final String requiredItemType;
  final List<String> options;
  final String instructionDe;
  final String instructionRu;

  String get itemKey => '$requiredItemType:$lemma';
}

enum GrammarExerciseType {
  text('text'),
  choice('choice'),
  yesNo('yes_no'),
  wordOrder('word_order');

  const GrammarExerciseType(this.wireName);

  final String wireName;

  static GrammarExerciseType fromWireName(String value) => values.firstWhere(
        (type) => type.wireName == value,
        orElse: () => throw FormatException(
          'Unknown grammar exercise type: $value',
        ),
      );
}

final class GrammarTopicProgress {
  const GrammarTopicProgress({
    required this.topicId,
    required this.learned,
    required this.updatedAt,
  });

  final String topicId;
  final bool learned;
  final DateTime updatedAt;
}

final class GrammarAttempt {
  const GrammarAttempt({
    required this.id,
    required this.topicId,
    required this.exerciseId,
    required this.sessionId,
    required this.answerText,
    required this.correct,
    required this.attemptedAt,
  });

  final String id;
  final String topicId;
  final String exerciseId;
  final String sessionId;
  final String answerText;
  final bool correct;
  final DateTime attemptedAt;
}

final class GrammarSummary {
  const GrammarSummary({required this.attempts, required this.correct});

  final int attempts;
  final int correct;

  int get errors => attempts - correct;
  double get accuracy => attempts == 0 ? 0 : correct / attempts;
}
