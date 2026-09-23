import 'package:deutsch_review/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review rating wire names are stable', () {
    expect(
      ReviewRating.values.map((rating) => rating.wireName),
      <String>['again', 'hard', 'good', 'easy'],
    );
  });

  test('scheduler state is immutable from the domain boundary', () {
    final mutableState = <String, Object?>{'stability': 1.0};
    final schedule = ReviewSchedule(
      itemId: 'item-1',
      dueAt: DateTime.utc(2026, 9, 24),
      schedulerName: 'test-scheduler',
      schedulerVersion: '1',
      schedulerState: mutableState,
      updatedAt: DateTime.utc(2026, 9, 23),
    );

    mutableState['stability'] = 2.0;

    expect(schedule.schedulerState['stability'], 1.0);
    expect(
      () => schedule.schedulerState['stability'] = 3.0,
      throwsUnsupportedError,
    );
  });
}
