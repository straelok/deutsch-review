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

final class DailySession {
  const DailySession({
    required this.id,
    required this.localDate,
    required this.slot,
    required this.status,
    required this.targetAnswers,
    required this.answeredCount,
    required this.queueItemIds,
    required this.createdAt,
    required this.updatedAt,
    this.lastItemId,
    this.completedAt,
  });

  final String id;
  final String localDate;
  final int? slot;
  final DailySessionStatus status;
  final int targetAnswers;
  final int answeredCount;
  final List<String> queueItemIds;
  final String? lastItemId;
  final DateTime createdAt;
  final DateTime updatedAt;
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
