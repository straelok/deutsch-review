import 'package:flutter/material.dart';

import 'domain/app_language.dart';
import 'domain/repositories/daily_session_repository.dart';
import 'domain/repositories/learning_item_repository.dart';
import 'domain/repositories/practice_repository.dart';
import 'domain/repositories/settings_repository.dart';
import 'features/material/material_page.dart';
import 'features/practice/practice_page.dart';
import 'features/statistics/statistics_page.dart';
import 'features/today/today_page.dart';
import 'l10n/ui_strings.dart';

class DeutschReviewApp extends StatefulWidget {
  const DeutschReviewApp({
    required this.learningItems,
    required this.sessions,
    required this.settings,
    required this.practice,
    this.onDispose,
    super.key,
  });

  final LearningItemRepository learningItems;
  final DailySessionRepository sessions;
  final SettingsRepository settings;
  final PracticeRepository practice;
  final VoidCallback? onDispose;

  @override
  State<DeutschReviewApp> createState() => _DeutschReviewAppState();
}

class _DeutschReviewAppState extends State<DeutschReviewApp> {
  AppLanguage _language = AppLanguage.german;

  @override
  void initState() {
    super.initState();
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
        language: _language,
        onLanguageChanged: _changeLanguage,
      ),
    );
  }

  Future<void> _loadLanguage() async {
    final language = await widget.settings.readLanguage();
    if (mounted) setState(() => _language = language);
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    setState(() => _language = language);
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
    required this.language,
    required this.onLanguageChanged,
    super.key,
  });

  final LearningItemRepository learningItems;
  final DailySessionRepository sessions;
  final PracticeRepository practice;
  final AppLanguage language;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _statisticsRevision = 0;
  String? _requestedSessionId;
  int _sessionRequestRevision = 0;

  @override
  Widget build(BuildContext context) {
    final s = UiStrings(widget.language);
    final destinations = <NavigationDestination>[
      NavigationDestination(
          icon: const Icon(Icons.today_outlined), label: s.today),
      NavigationDestination(
          icon: const Icon(Icons.school_outlined), label: s.learn),
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
      TodayPage(
        sessions: widget.sessions,
        strings: s,
        refreshToken: _statisticsRevision,
        onOpenSession: _openSession,
      ),
      PracticePage(
        learningItems: widget.learningItems,
        practice: widget.practice,
        sessions: widget.sessions,
        strings: s,
        requestedSessionId: _requestedSessionId,
        requestRevision: _sessionRequestRevision,
        onAttemptSaved: () => setState(() => _statisticsRevision++),
      ),
      DictionaryMaterialPage(
        repository: widget.learningItems,
        practice: widget.practice,
        strings: s,
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

  void _openSession(String id) {
    setState(() {
      _requestedSessionId = id;
      _sessionRequestRevision++;
      _selectedIndex = 1;
    });
  }
}
