import 'package:flutter/widgets.dart';

import '../domain/app_language.dart';
import '../domain/daily_session.dart';
import '../domain/repositories/daily_session_repository.dart';
import 'reminder_gateway.dart';

final class ReminderController extends ChangeNotifier
    with WidgetsBindingObserver {
  ReminderController({
    required DailySessionRepository sessions,
    required ReminderGateway gateway,
    Future<bool> Function()? grammarAvailability,
  })  : _sessions = sessions,
        _gateway = gateway,
        _grammarAvailability = grammarAvailability;

  final DailySessionRepository _sessions;
  final ReminderGateway _gateway;
  final Future<bool> Function()? _grammarAvailability;

  bool _enabled = false;
  bool _busy = false;
  int _openTodayRevision = 0;
  String? _lastDay;
  int? _lastCompleted;
  AppLanguage _language = AppLanguage.german;

  bool get isSupported => _gateway.isSupported;
  bool get isEnabled => _enabled;
  bool get isBusy => _busy;
  int get openTodayRevision => _openTodayRevision;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final launchedFromReminder = await _gateway.initialize(_openToday);
    _enabled = await _gateway.notificationsEnabled();
    if (launchedFromReminder) _openToday();
    await refresh(force: true);
    notifyListeners();
  }

  Future<void> requestPermission() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      _enabled = await _gateway.requestPermissions();
      await refresh(force: true);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (!isSupported) return;
    final now = DateTime.now();
    final day = localDayKey(now);
    final sessions = await _sessions.ensureDay(
      localDate: day,
      now: now.toUtc(),
      includeGrammar: await _grammarAvailability?.call() ?? false,
    );
    final completed = sessions
        .where((session) => session.isRequired && session.isComplete)
        .length;
    _enabled = await _gateway.notificationsEnabled();
    if (!force && _lastDay == day && _lastCompleted == completed) return;
    _lastDay = day;
    _lastCompleted = completed;
    await _gateway.replaceSchedule(
      now: now,
      skipToday:
          completed >= sessions.where((session) => session.isRequired).length,
      copy: _language == AppLanguage.russian
          ? const ReminderCopy(
              title: 'Worttrieb: занятия на сегодня',
              body: 'У вас остались незавершённые занятия.',
            )
          : const ReminderCopy(
              title: 'Worttrieb: heutige Sitzungen',
              body: 'Du hast noch nicht abgeschlossene Sitzungen.',
            ),
    );
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(force: true);
  }

  void _openToday() {
    _openTodayRevision++;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
