final class AppSettings {
  const AppSettings({
    this.includeImportantLessons = true,
    this.toGermanLessons = 3,
    this.toGermanTasks = 20,
    this.toRussianLessons = 3,
    this.toRussianTasks = 20,
    this.numberLessons = 2,
    this.numberTasks = 20,
    this.grammarLessons = 2,
    this.grammarTasks = 10,
    this.remindersEnabled = true,
    this.reminderMinutes = const [810, 990, 1170],
  });

  final bool includeImportantLessons;
  final int toGermanLessons;
  final int toGermanTasks;
  final int toRussianLessons;
  final int toRussianTasks;
  final int numberLessons;
  final int numberTasks;
  final int grammarLessons;
  final int grammarTasks;
  final bool remindersEnabled;
  final List<int> reminderMinutes;

  AppSettings copyWith({
    bool? includeImportantLessons,
    int? toGermanLessons,
    int? toGermanTasks,
    int? toRussianLessons,
    int? toRussianTasks,
    int? numberLessons,
    int? numberTasks,
    int? grammarLessons,
    int? grammarTasks,
    bool? remindersEnabled,
    List<int>? reminderMinutes,
  }) =>
      AppSettings(
        includeImportantLessons:
            includeImportantLessons ?? this.includeImportantLessons,
        toGermanLessons: toGermanLessons ?? this.toGermanLessons,
        toGermanTasks: toGermanTasks ?? this.toGermanTasks,
        toRussianLessons: toRussianLessons ?? this.toRussianLessons,
        toRussianTasks: toRussianTasks ?? this.toRussianTasks,
        numberLessons: numberLessons ?? this.numberLessons,
        numberTasks: numberTasks ?? this.numberTasks,
        grammarLessons: grammarLessons ?? this.grammarLessons,
        grammarTasks: grammarTasks ?? this.grammarTasks,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );

  Map<String, Object?> toJson() => {
        'includeImportantLessons': includeImportantLessons,
        'toGermanLessons': toGermanLessons,
        'toGermanTasks': toGermanTasks,
        'toRussianLessons': toRussianLessons,
        'toRussianTasks': toRussianTasks,
        'numberLessons': numberLessons,
        'numberTasks': numberTasks,
        'grammarLessons': grammarLessons,
        'grammarTasks': grammarTasks,
        'remindersEnabled': remindersEnabled,
        'reminderMinutes': reminderMinutes,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
        includeImportantLessons:
            json['includeImportantLessons'] as bool? ?? true,
        toGermanLessons: _bounded(json['toGermanLessons'], 3, 0, 10),
        toGermanTasks: _bounded(json['toGermanTasks'], 20, 1, 50),
        toRussianLessons: _bounded(json['toRussianLessons'], 3, 0, 10),
        toRussianTasks: _bounded(json['toRussianTasks'], 20, 1, 50),
        numberLessons: _bounded(json['numberLessons'], 2, 0, 10),
        numberTasks: _bounded(json['numberTasks'], 20, 1, 50),
        grammarLessons: _bounded(json['grammarLessons'], 2, 0, 10),
        grammarTasks: _bounded(json['grammarTasks'], 10, 1, 50),
        remindersEnabled: json['remindersEnabled'] as bool? ?? true,
        reminderMinutes: _minutes(json['reminderMinutes']),
      );

  static int _bounded(Object? value, int fallback, int min, int max) {
    if (value is! int) return fallback;
    return value.clamp(min, max);
  }

  static List<int> _minutes(Object? value) {
    if (value is! List) return const [810, 990, 1170];
    final result = value
        .whereType<int>()
        .where((minute) => minute >= 0 && minute < 1440)
        .toSet()
        .toList()
      ..sort();
    return result.take(5).toList(growable: false);
  }
}
