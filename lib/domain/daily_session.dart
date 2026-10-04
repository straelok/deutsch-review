const bundledContentVersion = '2026.10.04.1';

enum DailySessionStatus {
  planned('planned'),
  inProgress('in_progress'),
  completed('completed');

  const DailySessionStatus(this.wireName);

  final String wireName;

  static DailySessionStatus fromWireName(String value) {
    return values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown status'),
    );
  }
}

enum DailySessionKind {
  vocabularyToGerman('vocabulary_to_german'),
  vocabularyToRussian('vocabulary_to_russian'),
  importantVocabularyToGerman('important_vocabulary_to_german'),
  importantVocabularyToRussian('important_vocabulary_to_russian'),
  grammar('grammar'),
  numbers('numbers');

  const DailySessionKind(this.wireName);

  final String wireName;

  static DailySessionKind fromWireName(String value) {
    if (value == 'vocabulary') return vocabularyToGerman;
    return values.firstWhere(
      (kind) => kind.wireName == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown kind'),
    );
  }

  bool get isVocabulary => switch (this) {
        vocabularyToGerman ||
        vocabularyToRussian ||
        importantVocabularyToGerman ||
        importantVocabularyToRussian =>
          true,
        grammar || numbers => false,
      };

  bool get isToRussian => switch (this) {
        vocabularyToRussian || importantVocabularyToRussian => true,
        _ => false,
      };

  bool get isImportantVocabulary => switch (this) {
        importantVocabularyToGerman || importantVocabularyToRussian => true,
        _ => false,
      };
}

final class DailySession {
  const DailySession({
    required this.id,
    required this.localDate,
    required this.slot,
    required this.kind,
    required this.status,
    required this.targetAnswers,
    required this.answeredCount,
    required this.queueItemIds,
    required this.createdAt,
    required this.updatedAt,
    this.contentVersion = bundledContentVersion,
    this.lastItemId,
    this.completedAt,
  });

  final String id;
  final String localDate;
  final int? slot;
  final DailySessionKind kind;
  final DailySessionStatus status;
  final int targetAnswers;
  final int answeredCount;
  final List<String> queueItemIds;
  final String? lastItemId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String contentVersion;
  final DateTime? completedAt;

  bool get isRequired => slot != null;
  bool get isComplete => status == DailySessionStatus.completed;
  int get remaining => targetAnswers - answeredCount;
}

String localDayKey(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
