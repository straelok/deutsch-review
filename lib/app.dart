import 'package:flutter/material.dart';

import 'domain/repositories/learning_item_repository.dart';
import 'features/material/material_page.dart';

class DeutschReviewApp extends StatefulWidget {
  const DeutschReviewApp({
    required this.repository,
    this.onDispose,
    super.key,
  });

  final LearningItemRepository repository;
  final VoidCallback? onDispose;

  @override
  State<DeutschReviewApp> createState() => _DeutschReviewAppState();
}

class _DeutschReviewAppState extends State<DeutschReviewApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Deutsch Review',
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
      home: HomeScreen(repository: widget.repository),
    );
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
                  'Die lokale Datenbank konnte nicht geöffnet werden.',
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
  const HomeScreen({required this.repository, super.key});

  final LearningItemRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Heute'),
    NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Lernen'),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      label: 'Material',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const _EmptyPage(
        icon: Icons.today_outlined,
        title: 'Heute',
        message: 'Für heute sind noch keine Wiederholungen geplant.',
      ),
      const _EmptyPage(
        icon: Icons.school_outlined,
        title: 'Lernen',
        message: 'Deine nächste Lerneinheit erscheint hier.',
      ),
      DictionaryMaterialPage(repository: widget.repository),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 720;
        final content = IndexedStack(index: _selectedIndex, children: pages);

        return Scaffold(
          appBar: AppBar(title: const Text('Deutsch Review')),
          body: useRail
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: _destinations
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
                  destinations: _destinations,
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
