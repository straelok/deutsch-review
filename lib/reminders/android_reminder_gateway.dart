import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_gateway.dart';

final class AndroidReminderGateway implements ReminderGateway {
  AndroidReminderGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _payload = 'open_today';
  static const _channelId = 'daily_lessons';
  static const _firstNotificationId = 3200;
  static const _daysScheduled = 30;
  static const _times = <(int, int)>[(13, 30), (16, 30), (19, 30)];

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get isSupported => true;

  @override
  Future<bool> initialize(void Function() onOpenToday) async {
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == _payload) onOpenToday();
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true &&
        launch?.notificationResponse?.payload == _payload;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> notificationsEnabled() async {
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermissions() async {
    final notifications =
        await _android?.requestNotificationsPermission() ?? false;
    if (!notifications) return false;
    if (await _android?.canScheduleExactNotifications() != true) {
      await _android?.requestExactAlarmsPermission();
    }
    return true;
  }

  @override
  Future<void> replaceSchedule({
    required DateTime now,
    required bool skipToday,
    required ReminderCopy copy,
  }) async {
    await _plugin.cancelAllPendingNotifications();
    if (!await notificationsEnabled()) return;

    final exact = await _android?.canScheduleExactNotifications() == true;
    final localNow = tz.TZDateTime.from(now, tz.local);
    var id = _firstNotificationId;
    for (var dayOffset = 0; dayOffset < _daysScheduled; dayOffset++) {
      if (dayOffset == 0 && skipToday) {
        id += _times.length;
        continue;
      }
      final day = tz.TZDateTime(
        tz.local,
        localNow.year,
        localNow.month,
        localNow.day + dayOffset,
      );
      for (final (hour, minute) in _times) {
        final scheduled = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        );
        if (scheduled.isAfter(localNow)) {
          await _plugin.zonedSchedule(
            id: id,
            title: copy.title,
            body: copy.body,
            scheduledDate: scheduled,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                _channelId,
                'Tägliche Übungen',
                channelDescription:
                    'Erinnerungen an noch offene tägliche Sitzungen',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            androidScheduleMode: exact
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
            payload: _payload,
          );
        }
        id++;
      }
    }
  }
}
