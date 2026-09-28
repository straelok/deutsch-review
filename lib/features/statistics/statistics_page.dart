import 'package:flutter/material.dart';

import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/daily_session.dart';
import '../../domain/repositories/daily_session_repository.dart';
import '../../domain/repositories/grammar_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../l10n/ui_strings.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    required this.repository,
    required this.grammar,
    required this.sessions,
    required this.strings,
    required this.refreshToken,
    super.key,
  });

  final PracticeRepository repository;
  final GrammarRepository grammar;
  final DailySessionRepository sessions;
  final UiStrings strings;
  final int refreshToken;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  PracticeSummary? _summary;
  List<ItemPracticeSummary> _problems = const [];
  int? _completedToday;
  int? _requiredToday;
  PracticeSummary? _wordsToday;
  PracticeSummary? _numbersToday;
  PracticeSummary? _grammarToday;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant StatisticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final s = widget.strings;
    if (summary == null ||
        _completedToday == null ||
        _requiredToday == null ||
        _wordsToday == null ||
        _numbersToday == null ||
        _grammarToday == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.statistics, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        Text(s.todayStatistics, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        _Metric(
          label: s.dailyPlan,
          value: '${_completedToday!}/${_requiredToday!}',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DailyCategoryStatistics(
              key: const Key('daily-statistics-words'),
              icon: Icons.translate,
              title: s.wordsCategory,
              summary: _wordsToday!,
              strings: s,
            ),
            _DailyCategoryStatistics(
              key: const Key('daily-statistics-numbers'),
              icon: Icons.numbers,
              title: s.numbersCategory,
              summary: _numbersToday!,
              strings: s,
            ),
            _DailyCategoryStatistics(
              key: const Key('daily-statistics-grammar'),
              icon: Icons.school_outlined,
              title: s.grammarCategory,
              summary: _grammarToday!,
              strings: s,
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          s.allTimeWordsStatistics,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (summary.attempts == 0) ...[
          const SizedBox(height: 20),
          Text(s.statsEmpty),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(label: s.attempts, value: '${summary.attempts}'),
              _Metric(label: s.correctAnswers, value: '${summary.correct}'),
              _Metric(label: s.errors, value: '${summary.errors}'),
              _Metric(
                label: s.accuracy,
                value: '${(summary.accuracy * 100).round()} %',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(s.problemWords, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_problems.isEmpty)
            Text(s.choose('Keine Problemwörter.', 'Проблемных слов нет.'))
          else
            ..._problems.map(
              (problem) => Card(
                child: ListTile(
                  title: Text(learningItemGerman(problem.item)),
                  subtitle: Text(
                    '${s.errorCount(problem.errors)} · '
                    '${s.accuracy}: ${(problem.accuracy * 100).round()} %',
                  ),
                  trailing: Text('${problem.correct}/${problem.attempts}'),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _reload() async {
    final now = DateTime.now();
    final summaryFuture = widget.repository.summary();
    final problemsFuture = widget.repository.problemItems();
    final wordsTodayFuture = widget.repository.summaryForDay(now);
    final numbersTodayFuture = widget.grammar.summaryForDay(
      now,
      numbers: true,
    );
    final grammarTodayFuture = widget.grammar.summaryForDay(
      now,
      numbers: false,
    );
    final daySessions = await widget.sessions.ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
    );
    final summary = await summaryFuture;
    final problems = await problemsFuture;
    final wordsToday = await wordsTodayFuture;
    final numbersToday = await numbersTodayFuture;
    final grammarToday = await grammarTodayFuture;
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _problems = problems;
      _wordsToday = wordsToday;
      _numbersToday = PracticeSummary(
        attempts: numbersToday.attempts,
        correct: numbersToday.correct,
      );
      _grammarToday = PracticeSummary(
        attempts: grammarToday.attempts,
        correct: grammarToday.correct,
      );
      _completedToday = daySessions
          .where((session) => session.isRequired && session.isComplete)
          .length;
      _requiredToday =
          daySessions.where((session) => session.isRequired).length;
    });
  }
}

class _DailyCategoryStatistics extends StatelessWidget {
  const _DailyCategoryStatistics({
    required this.icon,
    required this.title,
    required this.summary,
    required this.strings,
    super.key,
  });

  final IconData icon;
  final String title;
  final PracticeSummary summary;
  final UiStrings strings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('${strings.attempts}: ${summary.attempts}'),
              Text('${strings.correctAnswers}: ${summary.correct}'),
              Text('${strings.errors}: ${summary.errors}'),
              Text(
                '${strings.accuracy}: '
                '${(summary.accuracy * 100).round()} %',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
