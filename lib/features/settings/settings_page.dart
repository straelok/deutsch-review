import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../l10n/ui_strings.dart';
import '../../reminders/reminder_controller.dart';

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
  AppSettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(title: Text(s.choose('Einstellungen', 'Настройки'))),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  s.choose('Tagesplan', 'План занятий'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const Key('include-important-lessons'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.choose(
                    'Lektionen mit wichtigen Wörtern',
                    'Уроки с важными словами',
                  )),
                  subtitle: Text(s.choose(
                    'Zeigt die beiden zusätzlichen Kategorien im Tagesplan.',
                    'Показывает две дополнительные категории в плане.',
                  )),
                  value: settings.includeImportantLessons,
                  onChanged: (value) => _update(
                    settings.copyWith(includeImportantLessons: value),
                  ),
                ),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('save-settings'),
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(s.save),
                ),
              ],
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

  Widget _counter({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) =>
      Row(
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
    if (mounted) setState(() => _settings = settings);
  }

  void _update(AppSettings settings) => setState(() => _settings = settings);

  Future<void> _changeTime(int index) async {
    final value = _settings!.reminderMinutes[index];
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60),
    );
    if (selected == null || !mounted) return;
    final times = [..._settings!.reminderMinutes];
    times[index] = selected.hour * 60 + selected.minute;
    _update(_settings!.copyWith(reminderMinutes: _sorted(times)));
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
    _update(_settings!.copyWith(reminderMinutes: _sorted(times)));
  }

  void _removeTime(int index) {
    final times = [..._settings!.reminderMinutes]..removeAt(index);
    _update(_settings!.copyWith(reminderMinutes: times));
  }

  static List<int> _sorted(List<int> values) =>
      (values.toSet().toList()..sort());

  String _formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.repository.saveAppSettings(_settings!);
    await widget.reminders?.settingsChanged();
    if (mounted) Navigator.of(context).pop(true);
  }
}
