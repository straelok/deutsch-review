import 'package:flutter/material.dart';

import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../l10n/ui_strings.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    required this.repository,
    required this.strings,
    required this.refreshToken,
    super.key,
  });

  final PracticeRepository repository;
  final UiStrings strings;
  final int refreshToken;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  PracticeSummary? _summary;
  List<ItemPracticeSummary> _problems = const [];

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
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summary.attempts == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.statsEmpty, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.statistics, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
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
    );
  }

  Future<void> _reload() async {
    final summary = await widget.repository.summary();
    final problems = await widget.repository.problemItems();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _problems = problems;
    });
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
