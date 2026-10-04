import 'package:flutter/widgets.dart';

import '../domain/app_language.dart';
import '../domain/daily_session.dart';
import '../domain/app_settings.dart';
import '../domain/repositories/daily_session_repository.dart';
import '../domain/repositories/settings_repository.dart';
import 'reminder_gateway.dart';

final class ReminderController extends ChangeNotifier
    with WidgetsBindingObserver {
  ReminderController({
    required DailySessionRepository sessions,
    required ReminderGateway gateway,
    SettingsRepository? settings,
    Future<bool> Function()? grammarAvailability,
  })  : _sessions = sessions,
        _gateway = gateway,
        _settings = settings,
        _grammarAvailability = grammarAvailability;

  final DailySessionRepository _sessions;
  final ReminderGateway _gateway;
  final SettingsRepository? _settings;
  final Future<bool> Function()? _grammarAvailability;

  bool _enabled = false;
  bool _busy = false;
  bool _initialized = false;
  Future<void>? _initialization;
  int _openTodayRevision = 0;
  String? _lastDay;
  int? _lastCompleted;
  AppLanguage _language = AppLanguage.german;
  AppSettings _appSettings = const AppSettings();

  bool get isSupported => _gateway.isSupported;
  bool get isEnabled => _enabled;
  bool get isBusy => _busy;
  int get openTodayRevision => _openTodayRevision;

  Future<void> initialize() async {
    if (_initialization case final initialization?) return initialization;
    final initialization = _initialize();
    _initialization = initialization;
    return initialization;
  }

  Future<void> _initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final launchedFromReminder = await _gateway.initialize(_openToday);
    _initialized = true;
    _appSettings = await _settings?.readAppSettings() ?? const AppSettings();
    _enabled =
        _appSettings.remindersEnabled && await _gateway.notificationsEnabled();
    if (launchedFromReminder) _openToday();
    await refresh(force: true);
    notifyListeners();
  }

  Future<void> requestPermission() async {
    if (_busy) return;
    _busy = true;
    notifyListeners();
    try {
      final granted = await _gateway.requestPermissions();
      _appSettings = _appSettings.copyWith(remindersEnabled: granted);
      await _settings?.saveAppSettings(_appSettings);
      _enabled = granted;
      await refresh(force: true);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> settingsChanged() async {
    _appSettings = await _settings?.readAppSettings() ?? const AppSettings();
    if (_appSettings.remindersEnabled &&
        !await _gateway.notificationsEnabled()) {
      await requestPermission();
      return;
    }
    await refresh(force: true);
  }

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    if (_initialized) refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (!isSupported || !_initialized) return;
    _appSettings = await _settings?.readAppSettings() ?? const AppSettings();
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
    _enabled =
        _appSettings.remindersEnabled && await _gateway.notificationsEnabled();
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
      reminderMinutes: _appSettings.remindersEnabled
          ? _appSettings.reminderMinutes
          : const [],
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
    if (_initialized) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
