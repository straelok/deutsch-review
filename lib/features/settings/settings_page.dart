import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../l10n/ui_strings.dart';
import '../../reminders/reminder_controller.dart';
import '../../ui/responsive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.repository,
    required this.strings,
    this.reminders,
    super.key,
  });

  final SettingsRepository repository;
  final UiStrings strings;
  final ReminderController? reminders;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _problemWeightController = TextEditingController();
  AppSettings? _settings;
  String? _problemWeightError;
  bool _saving = false;
  bool _savedOnce = false;
  Object? _saveError;
  int _saveRevision = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _problemWeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.choose('Einstellungen', 'Настройки')),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_saveError != null)
            IconButton(
              tooltip: s.choose(
                'Speichern fehlgeschlagen',
                'Не удалось сохранить',
              ),
              onPressed: _settings == null
                  ? null
                  : () => unawaited(
                        _persist(_settings!, refreshReminders: true),
                      ),
              icon: const Icon(Icons.sync_problem_outlined),
            )
          else if (_savedOnce)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Tooltip(
                message: s.choose('Gespeichert', 'Сохранено'),
                child: const Icon(Icons.cloud_done_outlined),
              ),
            ),
        ],
      ),
      body: SafeArea(
        key: const Key('settings-safe-area'),
        top: false,
        minimum: const EdgeInsets.only(bottom: 16),
        child: settings == null
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: ListView(
                    padding: AppLayout.pagePadding(context),
                    children: [
                      Text(
                        s.choose(
                          'Änderungen werden automatisch gespeichert.',
                          'Изменения сохраняются автоматически.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        s.choose('Tagesplan', 'План занятий'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(height: 32),
                      _problemWordWeight(settings),
                      const Divider(height: 32),
                      _answerBehavior(settings),
                      const Divider(height: 32),
                      _lessonGroup(
                        title: s.toGermanCategory,
                        lessons: settings.toGermanLessons,
                        tasks: settings.toGermanTasks,
                        onLessons: (value) => _update(
                          settings.copyWith(toGermanLessons: value),
                        ),
                        onTasks: (value) => _update(
                          settings.copyWith(toGermanTasks: value),
                        ),
                      ),
                      _lessonGroup(
                        title: s.toRussianCategory,
                        lessons: settings.toRussianLessons,
                        tasks: settings.toRussianTasks,
                        onLessons: (value) => _update(
                          settings.copyWith(toRussianLessons: value),
                        ),
                        onTasks: (value) => _update(
                          settings.copyWith(toRussianTasks: value),
                        ),
                      ),
                      _lessonGroup(
                        title: s.numbersCategory,
                        lessons: settings.numberLessons,
                        tasks: settings.numberTasks,
                        onLessons: (value) => _update(
                          settings.copyWith(numberLessons: value),
                        ),
                        onTasks: (value) => _update(
                          settings.copyWith(numberTasks: value),
                        ),
                      ),
                      _lessonGroup(
                        title: s.grammarCategory,
                        lessons: settings.grammarLessons,
                        tasks: settings.grammarTasks,
                        onLessons: (value) => _update(
                          settings.copyWith(grammarLessons: value),
                        ),
                        onTasks: (value) => _update(
                          settings.copyWith(grammarTasks: value),
                        ),
                      ),
                      _matchingDifficulty(settings),
                      const SizedBox(height: 16),
                      Text(
                        s.remindersTitle,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        key: const Key('reminders-enabled'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.choose(
                          'Benachrichtigungen verwenden',
                          'Использовать уведомления',
                        )),
                        subtitle: widget.reminders == null
                            ? Text(s.choose(
                                'Benachrichtigungen werden derzeit nur auf Android unterstützt.',
                                'Уведомления пока поддерживаются только на Android.',
                              ))
                            : null,
                        value: settings.remindersEnabled,
                        onChanged: (value) => _update(
                          settings.copyWith(remindersEnabled: value),
                          refreshReminders: true,
                        ),
                      ),
                      if (settings.remindersEnabled) ...[
                        ...settings.reminderMinutes.indexed.map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule_outlined),
                            title: Text(_formatTime(entry.$2)),
                            onTap: () => _changeTime(entry.$1),
                            trailing: IconButton(
                              tooltip: s.choose('Entfernen', 'Удалить'),
                              onPressed: () => _removeTime(entry.$1),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        ),
                        if (settings.reminderMinutes.length < 5)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              key: const Key('add-reminder-time'),
                              onPressed: _addTime,
                              icon: const Icon(Icons.add),
                              label: Text(s.choose(
                                'Erinnerungszeit hinzufügen',
                                'Добавить время напоминания',
                              )),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _answerBehavior(AppSettings settings) {
    final s = widget.strings;
    return Card(
      child: SwitchListTile(
        key: const Key('repeat-incorrect-immediately'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        secondary: const Icon(Icons.replay),
        title: Text(s.choose(
          'Fehler sofort korrigieren',
          'Исправлять ошибку сразу',
        )),
        subtitle: Text(s.choose(
          'Nach einer falschen Antwort wird dieselbe Karte bis zur richtigen Korrektur wiederholt. Später folgt eine Kontrollwiederholung.',
          'После ошибки эта же карточка повторяется до правильного ответа, а затем возвращается ещё раз для контрольной проверки.',
        )),
        value: settings.repeatIncorrectImmediately,
        onChanged: (value) => _update(
          settings.copyWith(repeatIncorrectImmediately: value),
        ),
      ),
    );
  }

  Widget _lessonGroup({
    required String title,
    required int lessons,
    required int tasks,
    required ValueChanged<int> onLessons,
    required ValueChanged<int> onTasks,
  }) {
    final s = widget.strings;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _counter(
              label: s.choose('Lektionen', 'Уроков'),
              value: lessons,
              min: 0,
              max: 10,
              onChanged: onLessons,
            ),
            _counter(
              label: s.choose('Aufgaben pro Lektion', 'Заданий в уроке'),
              value: tasks,
              min: 1,
              max: 50,
              onChanged: onTasks,
            ),
          ],
        ),
      ),
    );
  }

  Widget _problemWordWeight(AppSettings settings) {
    final s = widget.strings;
    final mediumWeight =
        1 + ((settings.problemWordMaxWeight - 1) * 0.5).round();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.choose(
                'Gewicht problematischer Wörter',
                'Вес проблемных слов',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(s.choose(
              'Der Wert bestimmt, wie viel häufiger Wörter mit Fehlern ausgewählt werden. Er gilt nur für Wortschatzlektionen.',
              'Значение определяет, насколько чаще выбираются слова с ошибками. Оно действует только в словарных уроках.',
            )),
            const SizedBox(height: 12),
            TextField(
              key: const Key('problem-word-max-weight'),
              controller: _problemWeightController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: s.choose('Maximalgewicht', 'Максимальный вес'),
                suffixText: '×',
                errorText: _problemWeightError,
              ),
              onChanged: _changeProblemWeight,
            ),
            const SizedBox(height: 10),
            Text(s.choose(
              'Bei der aktuellen Einstellung: 0 % richtige Antworten = ${settings.problemWordMaxWeight}×, 50 % = $mediumWeight×, 100 % = 1×. Der Wert 10 entspricht dem bisherigen Verhalten; 1 schaltet die Verstärkung aus.',
              'При текущем значении: 0% правильных ответов = ${settings.problemWordMaxWeight}×, 50% = $mediumWeight×, 100% = 1×. Значение 10 соответствует прежней работе, а 1 отключает усиление.',
            )),
            const SizedBox(height: 6),
            Text(
              s.choose(
                'Formel: 1 + runden((1 − Erfolgsquote) × (Maximalgewicht − 1)). Zulässig: ganze Zahl von 1 bis 1 000 000.',
                'Формула: 1 + округление((1 − успешность) × (максимальный вес − 1)). Допустимо целое число от 1 до 1 000 000.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _matchingDifficulty(AppSettings settings) {
    final s = widget.strings;
    return Card(
      key: const Key('matching-difficulty-settings'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.matchingCategory,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(s.matchingBoardSizeHint),
            const SizedBox(height: 8),
            _counter(
              key: const Key('matching-pairs-per-board'),
              label: s.matchingBoardSize,
              value: settings.matchingPairsPerBoard,
              min: 2,
              max: 12,
              onChanged: (value) => _update(
                settings.copyWith(matchingPairsPerBoard: value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter({
    Key? key,
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) =>
      Row(
        key: key,
        children: [
          Expanded(child: Text(label)),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
              width: 36, child: Text('$value', textAlign: TextAlign.center)),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      );

  Future<void> _load() async {
    final settings = await widget.repository.readAppSettings();
    if (!mounted) return;
    _problemWeightController.text = '${settings.problemWordMaxWeight}';
    setState(() => _settings = settings);
  }

  void _update(
    AppSettings settings, {
    bool refreshReminders = false,
  }) {
    setState(() => _settings = settings);
    unawaited(_persist(settings, refreshReminders: refreshReminders));
  }

  void _changeProblemWeight(String value) {
    final parsed = int.tryParse(value);
    final valid = parsed != null && parsed >= 1 && parsed <= 1000000;
    setState(() {
      _problemWeightError = valid
          ? null
          : widget.strings.choose(
              'Gib eine ganze Zahl von 1 bis 1 000 000 ein.',
              'Введите целое число от 1 до 1 000 000.',
            );
      if (valid) {
        _settings = _settings!.copyWith(problemWordMaxWeight: parsed);
      }
    });
    if (valid) unawaited(_persist(_settings!));
  }

  Future<void> _changeTime(int index) async {
    final value = _settings!.reminderMinutes[index];
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (selected == null || !mounted) return;
    final times = [..._settings!.reminderMinutes];
    times[index] = selected.hour * 60 + selected.minute;
    _update(
      _settings!.copyWith(reminderMinutes: _sorted(times)),
      refreshReminders: true,
    );
  }

  Future<void> _addTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (selected == null || !mounted) return;
    final times = [
      ..._settings!.reminderMinutes,
      selected.hour * 60 + selected.minute,
    ];
    _update(
      _settings!.copyWith(reminderMinutes: _sorted(times)),
      refreshReminders: true,
    );
  }

  void _removeTime(int index) {
    final times = [..._settings!.reminderMinutes]..removeAt(index);
    _update(
      _settings!.copyWith(reminderMinutes: times),
      refreshReminders: true,
    );
  }

  static List<int> _sorted(List<int> values) =>
      (values.toSet().toList()..sort());

  String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _persist(
    AppSettings settings, {
    bool refreshReminders = false,
  }) async {
    final revision = ++_saveRevision;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.repository.saveAppSettings(settings);
      if (refreshReminders) await widget.reminders?.settingsChanged();
      if (!mounted || revision != _saveRevision) return;
      setState(() {
        _saving = false;
        _savedOnce = true;
      });
    } catch (error) {
      if (!mounted || revision != _saveRevision) return;
      setState(() {
        _saving = false;
        _saveError = error;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (widget.strings.isRussian) {
            true => 'Не удалось сохранить настройки.',
            false => 'Die Einstellungen konnten nicht gespeichert werden.',
          }),
        ),
      );
    }
  }
}
