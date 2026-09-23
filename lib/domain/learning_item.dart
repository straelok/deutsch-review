enum LearningItemType {
  word('word'),
  noun('noun'),
  verb('verb'),
  phrase('phrase'),
  sentence('sentence'),
  grammarRule('grammar_rule'),
  ruleExample('rule_example'),
  fillGap('fill_gap'),
  wordOrder('word_order'),
  multipleChoice('multiple_choice');

  const LearningItemType(this.wireName);

  final String wireName;

  static LearningItemType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown type'),
    );
  }
}

final class LearningItem {
  LearningItem({
    required this.id,
    required this.type,
    required this.level,
    required this.lesson,
    required this.topic,
    required this.learned,
    required this.createdAt,
    required this.updatedAt,
    required this.sourceRef,
    required Map<String, Object?> content,
    this.deletedAt,
  }) : content = Map.unmodifiable(content);

  final String id;
  final LearningItemType type;
  final String level;
  final String lesson;
  final String topic;
  final bool learned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String sourceRef;
  final Map<String, Object?> content;

  bool get isAvailableForReview => learned && deletedAt == null;
}
