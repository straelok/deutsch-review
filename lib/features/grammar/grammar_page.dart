import 'package:flutter/material.dart';

import '../../domain/grammar.dart';
import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
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
    required this.onPracticeTopic,
    super.key,
  });

  final GrammarCatalog catalog;
  final GrammarRepository repository;
  final LearningItemRepository learningItems;
  final UiStrings strings;
  final int refreshToken;
  final VoidCallback onChanged;
  final ValueChanged<String> onPracticeTopic;

  @override
  State<GrammarPage> createState() => _GrammarPageState();
}

class _GrammarPageState extends State<GrammarPage> {
  Map<String, GrammarTopicProgress> _progress = const {};
  Map<String, GrammarSummary> _summaries = const {};
  Set<String> _activeItemKeys = const {};
  bool _loading = true;
  _TopicFilter _filter = _TopicFilter.all;

  static const _wordTopicIds = {
    'verb_basics',
    'infinitive_stem',
    'parts_of_speech',
    'noun_basics',
    'articles',
    'adjectives_adverbs',
    'prepositions',
  };

  static const _readingTopicIds = {
    'reading_vowels',
    'reading_consonants',
    'reading_stress',
  };

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
    final visibleTopics = topics.where((topic) {
      final learned = _progress[topic.id]?.learned ?? false;
      return switch (_filter) {
        _TopicFilter.all => true,
        _TopicFilter.notLearned => !learned,
        _TopicFilter.learned => learned,
      };
    }).toList(growable: false);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.grammar, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.grammarIntro),
        const SizedBox(height: 16),
        SegmentedButton<_TopicFilter>(
          segments: [
            ButtonSegment(
              value: _TopicFilter.all,
              label: Text(s.allLessons),
            ),
            ButtonSegment(
              value: _TopicFilter.notLearned,
              label: Text(s.notLearnedLessons),
            ),
            ButtonSegment(
              value: _TopicFilter.learned,
              label: Text(s.learnedLessons),
            ),
          ],
          selected: {_filter},
          onSelectionChanged: (selection) {
            setState(() => _filter = selection.single);
          },
        ),
        const SizedBox(height: 20),
        if (visibleTopics.isEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(
                _filter == _TopicFilter.learned
                    ? s.noLearnedLessons
                    : s.noLessonsForFilter,
              ),
            ),
          )
        else
          ..._categorySections(visibleTopics),
      ],
    );
  }

  List<Widget> _categorySections(List<GrammarTopic> topics) {
    final categories = <String, List<GrammarTopic>>{};
    for (final topic in topics) {
      categories.putIfAbsent(_category(topic.id), () => []).add(topic);
    }
    final result = <Widget>[];
    for (final category in const ['alphabet', 'numbers', 'grammar', 'words']) {
      final categoryTopics = categories[category];
      if (categoryTopics == null || categoryTopics.isEmpty) continue;
      if (result.isNotEmpty) result.add(const SizedBox(height: 20));
      result.add(
        Text(
          _categoryTitle(category),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      );
      result.add(const SizedBox(height: 8));
      result.addAll(categoryTopics.map(_topicCard));
    }
    return result;
  }

  String _category(String topicId) {
    if (topicId == 'alphabet' || _readingTopicIds.contains(topicId)) {
      return 'alphabet';
    }
    if (topicId == 'numbers') return 'numbers';
    if (_wordTopicIds.contains(topicId)) return 'words';
    return 'grammar';
  }

  String _categoryTitle(String category) => switch (category) {
        'alphabet' => widget.strings.alphabetCategory,
        'numbers' => widget.strings.numbersCategory,
        'words' => widget.strings.wordsCategory,
        _ => widget.strings.grammarCategory,
      };

  Widget _topicCard(GrammarTopic topic) {
    final s = widget.strings;
    final learned = _progress[topic.id]?.learned ?? false;
    final favorite = _progress[topic.id]?.favorite ?? false;
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
              learned
                  ? s.grammarLearned
                  : topic.trainable
                      ? available
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('toggle-favorite-topic-${topic.id}'),
              tooltip:
                  favorite ? s.removeGrammarFavorite : s.addGrammarFavorite,
              onPressed: () => _toggleFavorite(topic.id, !favorite),
              icon: Icon(favorite ? Icons.star : Icons.star_border),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
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
        favorite: _progress[topic.id]?.favorite ?? false,
        canLearn: _hasRequiredMaterial(topic.id),
        requiredMaterial: _requiredMaterial(topic.id),
        summary: _summaries[topic.id] ??
            const GrammarSummary(attempts: 0, correct: 0),
        onToggle: (learned) => widget.repository.setLearned(
          topicId: topic.id,
          learned: learned,
          now: DateTime.now().toUtc(),
        ),
        onFavorite: (favorite) => widget.repository.setFavorite(
          topicId: topic.id,
          favorite: favorite,
          now: DateTime.now().toUtc(),
        ),
        onAddAndLearn:
            topic.trainable ? () => _addRequiredMaterialAndLearn(topic) : null,
        onPractice:
            _canPractice(topic) ? () => widget.onPracticeTopic(topic.id) : null,
      ),
    );
    if (changed == true) {
      await _load();
      widget.onChanged();
    }
  }

  Future<void> _toggleFavorite(String topicId, bool favorite) async {
    await widget.repository.setFavorite(
      topicId: topicId,
      favorite: favorite,
      now: DateTime.now().toUtc(),
    );
    await _load();
    widget.onChanged();
  }

  bool _canPractice(GrammarTopic topic) =>
      topic.id == 'numbers' ||
      widget.catalog.exercises.any((exercise) => exercise.topicId == topic.id);

  bool _hasRequiredMaterial(String topicId) {
    final exercises = widget.catalog.exercises
        .where((exercise) => exercise.topicId == topicId)
        .toList(growable: false);
    if (exercises.isEmpty) return true;
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

  Future<void> _addRequiredMaterialAndLearn(GrammarTopic topic) async {
    final exercise = widget.catalog.exercises.firstWhere(
      (exercise) => exercise.topicId == topic.id,
    );
    if (!_activeItemKeys.contains(exercise.itemKey)) {
      final item = _learningItemFor(exercise);
      await widget.learningItems.save(item);
    }
    await widget.repository.setLearned(
      topicId: topic.id,
      learned: true,
      now: DateTime.now().toUtc(),
    );
  }

  LearningItem _learningItemFor(GrammarExercise exercise) {
    final now = DateTime.now().toUtc();
    final type = switch (exercise.requiredItemType) {
      'noun' => LearningItemType.noun,
      'verb' => LearningItemType.verb,
      _ => LearningItemType.word,
    };
    final content = <String, Object?>{
      'german': type == LearningItemType.noun
          ? '${exercise.lemma[0].toUpperCase()}${exercise.lemma.substring(1)}'
          : exercise.lemma,
      'translation_ru': _translation(exercise.lemma),
    };
    if (type == LearningItemType.noun) {
      final noun = _nounForms[exercise.lemma];
      content['article'] = noun?.$1 ?? 'der';
      content['plural'] = noun?.$2 ?? exercise.lemma;
    }
    return LearningItem(
      id: newUuidV4(),
      type: type,
      level: '',
      lesson: '',
      topic: '',
      learned: true,
      createdAt: now,
      updatedAt: now,
      sourceRef: 'grammar-assistant',
      content: content,
    );
  }

  static String _translation(String lemma) =>
      const {
        'lernen': 'учить',
        'wohnen': 'жить',
        'sein': 'быть',
        'haben': 'иметь',
        'tisch': 'стол',
        'klein': 'маленький',
        'in': 'в',
      }[lemma] ??
      lemma;

  static const _nounForms = <String, (String, String)>{
    'tisch': ('der', 'Tische'),
  };

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

enum _TopicFilter { all, notLearned, learned }

class _GrammarTopicDialog extends StatefulWidget {
  const _GrammarTopicDialog({
    required this.topic,
    required this.strings,
    required this.learned,
    required this.favorite,
    required this.canLearn,
    required this.requiredMaterial,
    required this.summary,
    this.onToggle,
    this.onFavorite,
    this.onAddAndLearn,
    this.onPractice,
  });

  final GrammarTopic topic;
  final UiStrings strings;
  final bool learned;
  final bool favorite;
  final bool canLearn;
  final String requiredMaterial;
  final GrammarSummary summary;
  final Future<void> Function(bool learned)? onToggle;
  final Future<void> Function(bool favorite)? onFavorite;
  final Future<void> Function()? onAddAndLearn;
  final VoidCallback? onPractice;

  @override
  State<_GrammarTopicDialog> createState() => _GrammarTopicDialogState();
}

class _GrammarTopicDialogState extends State<_GrammarTopicDialog> {
  late bool _learned = widget.learned;
  late bool _favorite = widget.favorite;
  bool _busy = false;
  bool _changed = false;

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
          onPressed: () => Navigator.pop(context, _changed),
          child: Text(s.close),
        ),
        if (widget.onToggle != null)
          FilledButton(
            key: Key('toggle-topic-${topic.id}'),
            onPressed: _busy ? null : _toggle,
            child: Text(_learned ? s.markNotLearned : s.markLearned),
          ),
        if (widget.onFavorite != null)
          OutlinedButton.icon(
            key: Key('dialog-toggle-favorite-topic-${topic.id}'),
            onPressed: _busy ? null : _toggleFavorite,
            icon: Icon(_favorite ? Icons.star : Icons.star_border),
            label: Text(
              _favorite ? s.removeGrammarFavorite : s.addGrammarFavorite,
            ),
          ),
        if (widget.onPractice != null)
          FilledButton.icon(
            key: Key('practice-topic-${topic.id}'),
            onPressed: _busy ? null : _practice,
            icon: const Icon(Icons.play_arrow),
            label: Text(s.practiceThisTheory),
          ),
      ],
    );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _busy = true);
    await widget.onFavorite!(!_favorite);
    if (!mounted) return;
    setState(() {
      _favorite = !_favorite;
      _busy = false;
      _changed = true;
    });
  }

  Future<void> _toggle() async {
    if (!widget.canLearn && !_learned) {
      final add = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.strings.addMaterial),
          content: Text(
            widget.strings.grammarAddMaterialQuestion(widget.requiredMaterial),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.strings.cancel),
            ),
            FilledButton(
              key: const Key('add-required-material'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.strings.addAndLearn),
            ),
          ],
        ),
      );
      if (add != true || widget.onAddAndLearn == null) return;
      setState(() => _busy = true);
      await widget.onAddAndLearn!();
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    }
    setState(() => _busy = true);
    await widget.onToggle!(!_learned);
    if (!mounted) return;
    setState(() {
      _learned = !_learned;
      _busy = false;
    });
    Navigator.pop(context, true);
  }

  Future<void> _practice() async {
    if (!widget.canLearn && !_learned) {
      final add = await _confirmAddMaterial();
      if (!add || widget.onAddAndLearn == null) return;
      setState(() => _busy = true);
      await widget.onAddAndLearn!();
    } else if (!_learned && widget.onToggle != null) {
      setState(() => _busy = true);
      await widget.onToggle!(true);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onPractice!());
  }

  Future<bool> _confirmAddMaterial() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(widget.strings.addMaterial),
            content: Text(
              widget.strings
                  .grammarAddMaterialQuestion(widget.requiredMaterial),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(widget.strings.cancel),
              ),
              FilledButton(
                key: const Key('add-required-material'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(widget.strings.addAndLearn),
              ),
            ],
          ),
        ) ??
        false;
  }
}
