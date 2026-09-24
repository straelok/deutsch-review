import 'package:flutter/material.dart';

import 'domain/app_language.dart';
import 'domain/repositories/daily_session_repository.dart';
import 'domain/repositories/learning_item_repository.dart';
import 'domain/repositories/practice_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'features/material/material_page.dart';
import 'features/practice/practice_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/sync/sync_dialog.dart';
import 'l10n/ui_strings.dart';
import 'reminders/reminder_controller.dart';
import 'sync/sync_controller.dart';
import 'sync/sync_models.dart';

class DeutschReviewApp extends StatefulWidget {
  const DeutschReviewApp({
    required this.learningItems,
    required this.sessions,
    required this.settings,
    required this.practice,
    this.syncController,
    this.reminders,
    this.onDispose,
    super.key,
  });

  final LearningItemRepository learningItems;
  final DailySessionRepository sessions;
  final SettingsRepository settings;
  final PracticeRepository practice;
  final SyncController? syncController;
  final ReminderController? reminders;
  final VoidCallback? onDispose;

  @override
  State<DeutschReviewApp> createState() => _DeutschReviewAppState();
}

class _DeutschReviewAppState extends State<DeutschReviewApp> {
  AppLanguage _language = AppLanguage.german;

  @override
  void initState() {
    super.initState();
    widget.reminders?.setLanguage(_language);
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Worttrieb',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7FB3A4),
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        learningItems: widget.learningItems,
        sessions: widget.sessions,
        practice: widget.practice,
        syncController: widget.syncController,
        reminders: widget.reminders,
        language: _language,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }

  Future<void> _loadLanguage() async {
    final language = await widget.settings.readLanguage();
    widget.reminders?.setLanguage(language);
    if (mounted) setState(() => _language = language);
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    setState(() => _language = language);
    widget.reminders?.setLanguage(language);
    await widget.settings.saveLanguage(language);
  }

  @override
  void dispose() {
    widget.onDispose?.call();
    super.dispose();
  }
}

class DatabaseErrorApp extends StatelessWidget {
  const DatabaseErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storage_outlined, size: 56),
                const SizedBox(height: 16),
                const Text(
                  'Die lokale Datenbank konnte nicht geöffnet werden.\n'
                  'Не удалось открыть локальную базу данных.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.learningItems,
    required this.sessions,
    required this.practice,
    this.syncController,
    this.reminders,
    required this.language,
    required this.onLanguageChanged,
    super.key,
  });

  final LearningItemRepository learningItems;
  final DailySessionRepository sessions;
  final PracticeRepository practice;
  final SyncController? syncController;
  final ReminderController? reminders;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _statisticsRevision = 0;
  int _lastSyncRevision = 0;
  int _lastReminderRevision = 0;

  @override
  void initState() {
    super.initState();
    final sync = widget.syncController;
    if (sync != null) {
      _lastSyncRevision = sync.dataRevision;
      sync.addListener(_syncChanged);
    }
    final reminders = widget.reminders;
    if (reminders != null) {
      _lastReminderRevision = reminders.openTodayRevision;
      reminders.addListener(_remindersChanged);
    }
    if (sync != null && sync.isConfigured && sync.nickname == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openSyncDialog();
      });
    }
  }

  @override
  void dispose() {
    widget.syncController?.removeListener(_syncChanged);
    widget.reminders?.removeListener(_remindersChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = UiStrings(widget.language);
    final destinations = <NavigationDestination>[
      NavigationDestination(
          icon: const Icon(Icons.today_outlined), label: s.today),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        label: s.material,
      ),
      NavigationDestination(
        icon: const Icon(Icons.insights_outlined),
        label: s.statistics,
      ),
    ];
    final pages = <Widget>[
      PracticePage(
        learningItems: widget.learningItems,
        practice: widget.practice,
        sessions: widget.sessions,
        strings: s,
        refreshToken: _statisticsRevision,
        onAttemptSaved: () => setState(() => _statisticsRevision++),
        reminders: widget.reminders,
      ),
      DictionaryMaterialPage(
        repository: widget.learningItems,
        practice: widget.practice,
        strings: s,
        refreshToken: _statisticsRevision,
      ),
      StatisticsPage(
        repository: widget.practice,
        sessions: widget.sessions,
        strings: s,
        refreshToken: _statisticsRevision,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Worttrieb'),
            actions: [
              PopupMenuButton<AppLanguage>(
                key: const Key('language-switch'),
                tooltip: s.switchLanguage,
                initialValue: widget.language,
                onSelected: widget.onLanguageChanged,
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language),
                    const SizedBox(width: 4),
                    Text(widget.language.code.toUpperCase()),
                  ],
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: AppLanguage.german,
                    child: Text('Deutsch'),
                  ),
                  PopupMenuItem(
                    value: AppLanguage.russian,
                    child: Text('Русский'),
                  ),
                ],
              ),
              if (widget.syncController case final sync?)
                AnimatedBuilder(
                  animation: sync,
                  builder: (context, _) => IconButton(
                    key: const Key('sync-settings'),
                    tooltip: s.syncTitle,
                    onPressed: _openSyncDialog,
                    icon: Icon(_syncIcon(sync.phase)),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: destinations
                          .map(
                            (destination) => NavigationRailDestination(
                              icon: destination.icon,
                              selectedIcon: destination.selectedIcon,
                              label: Text(destination.label),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: destinations,
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }

  void _syncChanged() {
    final sync = widget.syncController;
    if (sync == null || sync.dataRevision == _lastSyncRevision) return;
    _lastSyncRevision = sync.dataRevision;
    widget.reminders?.refresh(force: true);
    if (mounted) setState(() => _statisticsRevision++);
  }

  void _remindersChanged() {
    final reminders = widget.reminders;
    if (reminders == null ||
        reminders.openTodayRevision == _lastReminderRevision) {
      return;
    }
    _lastReminderRevision = reminders.openTodayRevision;
    if (mounted) setState(() => _selectedIndex = 0);
  }

  Future<void> _openSyncDialog() async {
    final sync = widget.syncController;
    if (sync == null) return;
    await showSyncDialog(
      context: context,
      controller: sync,
      strings: UiStrings(widget.language),
    );
  }

  static IconData _syncIcon(SyncPhase phase) => switch (phase) {
        SyncPhase.syncing => Icons.sync,
        SyncPhase.synced => Icons.cloud_done_outlined,
        SyncPhase.error || SyncPhase.unavailable => Icons.cloud_off_outlined,
        SyncPhase.disconnected || SyncPhase.idle => Icons.cloud_queue_outlined,
      };
}
