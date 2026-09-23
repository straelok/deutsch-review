final class ReminderCopy {
  const ReminderCopy({required this.title, required this.body});

  final String title;
  final String body;
}

abstract interface class ReminderGateway {
  bool get isSupported;

  Future<bool> initialize(void Function() onOpenToday);

  Future<bool> notificationsEnabled();

  Future<bool> requestPermissions();

  Future<void> replaceSchedule({
    required DateTime now,
    required bool skipToday,
    required ReminderCopy copy,
  });
}
