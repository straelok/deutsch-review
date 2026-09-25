import 'package:flutter/material.dart';

import '../../domain/grammar.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/repositories/grammar_repository.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../grammar/grammar_catalog.dart';
import '../../l10n/ui_strings.dart';

class GrammarPage extends StatefulWidget {
  const GrammarPage({
    required this.catalog,
    required this.repository,
    required this.learningItems,
    required this.strings,
    required this.refreshToken,
    required this.onChanged,
    super.key,
  });

  final GrammarCatalog catalog;
  final GrammarRepository repository;
  final LearningItemRepository learningItems;
  final UiStrings strings;
  final int refreshToken;
  final VoidCallback onChanged;

  @override
  State<GrammarPage> createState() => _GrammarPageState();
}

class _GrammarPageState extends State<GrammarPage> {
  Map<String, GrammarTopicProgress> _progress = const {};
  Map<String, GrammarSummary> _summaries = const {};
  Set<String> _activeItemKeys = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant GrammarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    final topics = [...widget.catalog.topics]
      ..sort((a, b) => a.order.compareTo(b.order));
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.grammar, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.grammarIntro),
        const SizedBox(height: 20),
        ...topics.map(_topicCard),
      ],
    );
  }

  Widget _topicCard(GrammarTopic topic) {
    final s = widget.strings;
    final learned = _progress[topic.id]?.learned ?? false;
    final available = _hasRequiredMaterial(topic.id);
    final summary =
        _summaries[topic.id] ?? const GrammarSummary(attempts: 0, correct: 0);
    return Card(
      child: ListTile(
        key: Key('grammar-topic-${topic.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: CircleAvatar(
          child: Icon(
            learned
                ? Icons.check
                : topic.trainable
                    ? Icons.school_outlined
                    : Icons.menu_book_outlined,
          ),
        ),
        title: Text(_title(topic)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_summary(topic)),
            const SizedBox(height: 4),
            Text(
              topic.trainable
                  ? learned
                      ? s.grammarLearned
                      : available
                          ? s.grammarReady
                          : s.grammarNeedsMaterial(
                              _requiredMaterial(topic.id),
                            )
                  : s.grammarReference,
            ),
            if (summary.attempts > 0)
              Text(
                '${s.attempts}: ${summary.attempts} · '
                '${s.accuracy}: ${(summary.accuracy * 100).round()} %',
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openTopic(topic),
      ),
    );
  }

  Future<void> _openTopic(GrammarTopic topic) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _GrammarTopicDialog(
        topic: topic,
        strings: widget.strings,
        learned: _progress[topic.id]?.learned ?? false,
        canLearn: _hasRequiredMaterial(topic.id),
        requiredMaterial: _requiredMaterial(topic.id),
        summary: _summaries[topic.id] ??
            const GrammarSummary(attempts: 0, correct: 0),
        onToggle: topic.trainable
            ? (learned) => widget.repository.setLearned(
                  topicId: topic.id,
                  learned: learned,
                  now: DateTime.now().toUtc(),
                )
            : null,
      ),
    );
    if (changed == true) {
      await _load();
      widget.onChanged();
    }
  }

  bool _hasRequiredMaterial(String topicId) {
    return widget.catalog
        .exercisesFor(topicId: topicId, activeItemKeys: _activeItemKeys)
        .isNotEmpty;
  }

  String _requiredMaterial(String topicId) {
    final examples = widget.catalog.exercises
        .where((exercise) => exercise.topicId == topicId)
        .map((exercise) => exercise.lemma)
        .toSet()
        .take(3)
        .join(', ');
    return examples.isEmpty
        ? widget.strings.choose('ein passendes Wort', 'подходящее слово')
        : examples;
  }

  String _title(GrammarTopic topic) =>
      widget.strings.isRussian ? topic.titleRu : topic.titleDe;

  String _summary(GrammarTopic topic) =>
      widget.strings.isRussian ? topic.summaryRu : topic.summaryDe;

  Future<void> _load() async {
    final items = await widget.learningItems.findActive();
    final progress = await widget.repository.progress();
    final summaries = <String, GrammarSummary>{};
    for (final topic in widget.catalog.topics) {
      summaries[topic.id] = await widget.repository.summary(topic.id);
    }
    if (!mounted) return;
    setState(() {
      _activeItemKeys = items
          .map(
            (item) => '${item.type.wireName}:'
                '${GrammarCatalog.normalizeLemma(learningItemGerman(item))}',
          )
          .toSet();
      _progress = progress;
      _summaries = summaries;
      _loading = false;
    });
  }
}

class _GrammarTopicDialog extends StatefulWidget {
  const _GrammarTopicDialog({
    required this.topic,
    required this.strings,
    required this.learned,
    required this.canLearn,
    required this.requiredMaterial,
    required this.summary,
    this.onToggle,
  });

  final GrammarTopic topic;
  final UiStrings strings;
  final bool learned;
  final bool canLearn;
  final String requiredMaterial;
  final GrammarSummary summary;
  final Future<void> Function(bool learned)? onToggle;

  @override
  State<_GrammarTopicDialog> createState() => _GrammarTopicDialogState();
}

class _GrammarTopicDialogState extends State<_GrammarTopicDialog> {
  late bool _learned = widget.learned;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final topic = widget.topic;
    final explanation = s.isRussian ? topic.explanationRu : topic.explanationDe;
    return AlertDialog(
      title: Text(s.isRussian ? topic.titleRu : topic.titleDe),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...explanation.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(paragraph),
                ),
              ),
              if (topic.table.isNotEmpty) ...[
                const SizedBox(height: 8),
                Table(
                  border: TableBorder.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  children: topic.table
                      .map(
                        (row) => TableRow(
                          children: row
                              .map(
                                (cell) => Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(cell),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (topic.trainable) ...[
                const SizedBox(height: 18),
                Text(
                  '${s.attempts}: ${widget.summary.attempts} · '
                  '${s.accuracy}: '
                  '${(widget.summary.accuracy * 100).round()} %',
                ),
                if (!widget.canLearn && !_learned) ...[
                  const SizedBox(height: 8),
                  Text(s.grammarNeedsMaterial(widget.requiredMaterial)),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.close),
        ),
        if (widget.onToggle != null)
          FilledButton(
            key: Key('toggle-topic-${topic.id}'),
            onPressed:
                _busy || (!widget.canLearn && !_learned) ? null : _toggle,
            child: Text(_learned ? s.markNotLearned : s.markLearned),
          ),
      ],
    );
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    await widget.onToggle!(!_learned);
    if (!mounted) return;
    setState(() {
      _learned = !_learned;
      _busy = false;
    });
    Navigator.pop(context, true);
  }
}
