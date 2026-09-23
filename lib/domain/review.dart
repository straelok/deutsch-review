enum ReviewRating {
  again('again'),
  hard('hard'),
  good('good'),
  easy('easy');

  const ReviewRating(this.wireName);

  final String wireName;

  static ReviewRating fromWireName(String value) {
    return values.firstWhere(
      (rating) => rating.wireName == value,
      orElse: () => throw ArgumentError.value(value, 'value', 'Unknown rating'),
    );
  }
}

final class ReviewSchedule {
  ReviewSchedule({
    required this.itemId,
    required this.dueAt,
    required this.schedulerName,
    required this.schedulerVersion,
    required Map<String, Object?> schedulerState,
    required this.updatedAt,
  }) : schedulerState = Map.unmodifiable(schedulerState);

  final String itemId;
  final DateTime dueAt;
  final String schedulerName;
  final String schedulerVersion;
  final Map<String, Object?> schedulerState;
  final DateTime updatedAt;
}

final class ReviewEvent {
  ReviewEvent({
    required this.id,
    required this.itemId,
    required this.sessionId,
    required this.rating,
    required this.reviewedAt,
    required this.schedulerName,
    required this.schedulerVersion,
    required Map<String, Object?> stateBefore,
    required Map<String, Object?> stateAfter,
  })  : stateBefore = Map.unmodifiable(stateBefore),
        stateAfter = Map.unmodifiable(stateAfter);

  final String id;
  final String itemId;
  final String sessionId;
  final ReviewRating rating;
  final DateTime reviewedAt;
  final String schedulerName;
  final String schedulerVersion;
  final Map<String, Object?> stateBefore;
  final Map<String, Object?> stateAfter;
}
