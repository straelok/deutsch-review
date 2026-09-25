import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/answer_checker.dart';
import '../../domain/daily_session.dart';
import '../../domain/grammar.dart';
import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/daily_session_repository.dart';
import '../../domain/repositories/grammar_repository.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../domain/word_priority.dart';
import '../../grammar/grammar_catalog.dart';
import '../../l10n/ui_strings.dart';
import '../../reminders/reminder_controller.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({
    required this.learningItems,
    required this.practice,
    required this.sessions,
    required this.grammar,
    required this.grammarCatalog,
    required this.strings,
    required this.refreshToken,
    required this.onAttemptSaved,
    this.reminders,
    super.key,
  });

  final LearningItemRepository learningItems;
  final PracticeRepository practice;
  final DailySessionRepository sessions;
  final GrammarRepository grammar;
  final GrammarCatalog grammarCatalog;
  final UiStrings strings;
  final int refreshToken;
  final VoidCallback onAttemptSaved;
  final ReminderController? reminders;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  final _random = Random();
  List<LearningItem> _activeItems = const [];
  List<LearningItem> _queue = const [];
  List<DailySession> _daySessions = const [];
  List<String> _grammarQueue = const [];
  List<String> _nextGrammarQueue = const [];
  Set<String> _availableGrammarTopics = const {};
  DailySession? _session;
  List<LearningItem> _nextQueue = const [];
  bool _loading = true;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _complete = false;
  Map<String, bool> _grammarResults = const {};
  final Map<String, TextEditingController> _grammarControllers = {};
  String? _selectedGrammarOption;
  List<int> _wordOrderSelection = const [];

  LearningItem? get _current => _queue.isEmpty ? null : _queue.first;
  String? get _currentGrammar =>
      _grammarQueue.isEmpty ? null : _grammarQueue.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken && _session == null) {
      _load();
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    for (final controller in _grammarControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_session == null) return _sessionSelection();
    if (_complete) {
      return _CenteredPanel(
        icon: Icons.celebration_outlined,
        title: s.sessionComplete,
        message: s.sessionCompleteHint,
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.today_outlined),
          label: Text(s.dailyPlan),
        ),
      );
    }

    if (_session!.kind == DailySessionKind.grammar) {
      return _grammarPractice();
    }

    final item = _current;
    if (item == null) {
      return _CenteredPanel(
        icon: Icons.school_outlined,
        title: s.learn,
        message: s.reviewEmpty,
      );
    }
    final expected = learningItemGerman(item);
    final note = learningItemNote(item);
    final example = learningItemExample(item);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('back-to-plan'),
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(s.dailyPlan),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.progress(
                      _session!.answeredCount,
                      _session!.targetAnswers,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    learningItemMeaning(item),
                    key: const Key('practice-prompt'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('practice-answer'),
                    controller: _answerController,
                    focusNode: _answerFocus,
                    enabled: !_answered,
                    decoration: InputDecoration(labelText: s.yourAnswer),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _answered ? null : _checkAnswer(),
                  ),
                  if (_answered) ...[
                    const SizedBox(height: 20),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: (_lastCorrect
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastCorrect ? s.correct : s.incorrect,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            if (!_lastCorrect) ...[
                              const SizedBox(height: 6),
                              Text(s.correctAnswer(expected)),
                            ],
                            if (example != null) ...[
                              const SizedBox(height: 6),
                              Text(s.exampleValue(example)),
                            ],
                            if (note != null) ...[
                              const SizedBox(height: 6),
                              Text(s.noteValue(note)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: Key(_answered ? 'next-answer' : 'check-answer'),
                    onPressed: _answered ? _next : _checkAnswer,
                    child: Text(_answered ? s.next : s.check),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionSelection() {
    final s = widget.strings;
    final requiredSessions =
        _daySessions.where((session) => session.isRequired).toList();
    final extraSessions =
        _daySessions.where((session) => !session.isRequired).toList();
    final completed =
        requiredSessions.where((session) => session.isComplete).length;
    final dayComplete =
        requiredSessions.isNotEmpty && completed == requiredSessions.length;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.dailyPlan, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.dailyProgress(completed, requiredSessions.length)),
        if (widget.reminders case final reminders?) ...[
          const SizedBox(height: 16),
          _reminderCard(reminders),
        ],
        if (_activeItems.isEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(s.reviewEmpty),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(s.chooseSession),
        const SizedBox(height: 8),
        ...requiredSessions.map(_sessionCard),
        if (dayComplete) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('create-extra-session'),
            onPressed: _createExtraSession,
            icon: const Icon(Icons.add),
            label: Text(s.getNewLesson),
          ),
        ],
        if (extraSessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(s.extraSession, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...extraSessions.map(_sessionCard),
        ],
      ],
    );
  }

  Widget _reminderCard(ReminderController reminders) {
    final s = widget.strings;
    return AnimatedBuilder(
      animation: reminders,
      builder: (context, _) => Card(
        child: ListTile(
          leading: Icon(
            reminders.isEnabled
                ? Icons.notifications_active_outlined
                : Icons.notifications_off_outlined,
          ),
          title: Text(s.remindersTitle),
          subtitle: Text(
            reminders.isEnabled ? s.remindersEnabled : s.remindersDisabled,
          ),
          trailing: reminders.isEnabled
              ? const Icon(Icons.check)
              : FilledButton(
                  key: const Key('enable-reminders'),
                  onPressed:
                      reminders.isBusy ? null : reminders.requestPermission,
                  child: reminders.isBusy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.enableReminders),
                ),
        ),
      ),
    );
  }

  Widget _grammarPractice() {
    final s = widget.strings;
    final taskId = _currentGrammar;
    if (taskId == null) {
      return _CenteredPanel(
        icon: Icons.school_outlined,
        title: s.grammar,
        message: s.grammarSessionUnavailable,
        action: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.arrow_back),
          label: Text(s.dailyPlan),
        ),
      );
    }
    final paradigm = _paradigm(taskId);
    final exercise =
        paradigm == null ? widget.grammarCatalog.exercise(taskId) : null;
    if (paradigm == null && exercise == null) {
      return _CenteredPanel(
        icon: Icons.error_outline,
        title: s.grammar,
        message: s.grammarSessionUnavailable,
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('back-to-plan'),
                      onPressed: _load,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(s.dailyPlan),
                    ),
                  ),
                  Text(
                    s.progress(
                      _session!.answeredCount,
                      _session!.targetAnswers,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 22),
                  if (paradigm != null)
                    _paradigmFields(paradigm)
                  else ...[
                    if (_exerciseInstruction(exercise!).isNotEmpty) ...[
                      Text(
                        _exerciseInstruction(exercise),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      exercise.prompt,
                      key: const Key('grammar-prompt'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 24),
                    _grammarExerciseInput(exercise),
                  ],
                  if (_answered) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: (_lastCorrect
                                ? Colors.green
                                : Theme.of(context).colorScheme.error)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_lastCorrect ? s.correct : s.incorrect),
                          if (!_lastCorrect && exercise != null)
                            Text(s.correctAnswer(exercise.answer)),
                          if (!_lastCorrect && paradigm != null)
                            ...paradigm.forms.entries.map(
                              (entry) => Text('${entry.key}: ${entry.value}'),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    key: Key(_answered
                        ? 'next-grammar-answer'
                        : 'check-grammar-answer'),
                    onPressed: _answered ? _nextGrammar : _checkGrammar,
                    child: Text(_answered ? s.next : s.check),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _grammarExerciseInput(GrammarExercise exercise) {
    final s = widget.strings;
    switch (exercise.type) {
      case GrammarExerciseType.text:
        return TextField(
          key: const Key('grammar-answer'),
          controller: _answerController,
          focusNode: _answerFocus,
          enabled: !_answered,
          decoration: InputDecoration(labelText: s.grammarEnding),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _answered ? null : _checkGrammar(),
        );
      case GrammarExerciseType.choice:
      case GrammarExerciseType.yesNo:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.chooseAnswer),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: exercise.options
                  .map(
                    (option) => ChoiceChip(
                      key: Key('grammar-option-$option'),
                      label: Text(option),
                      selected: _selectedGrammarOption == option,
                      onSelected: _answered
                          ? null
                          : (_) => setState(
                                () => _selectedGrammarOption = option,
                              ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        );
      case GrammarExerciseType.wordOrder:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.buildSentence),
            const SizedBox(height: 10),
            Container(
              key: const Key('grammar-word-order-answer'),
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_wordOrderAnswer(exercise)),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var index = 0; index < exercise.options.length; index++)
                  OutlinedButton(
                    key: Key('grammar-token-$index'),
                    onPressed: _answered || _wordOrderSelection.contains(index)
                        ? null
                        : () => setState(
                              () => _wordOrderSelection = [
                                ..._wordOrderSelection,
                                index,
                              ],
                            ),
                    child: Text(exercise.options[index]),
                  ),
              ],
            ),
            TextButton.icon(
              key: const Key('grammar-word-order-undo'),
              onPressed: _answered || _wordOrderSelection.isEmpty
                  ? null
                  : () => setState(
                        () => _wordOrderSelection = _wordOrderSelection
                            .take(_wordOrderSelection.length - 1)
                            .toList(growable: false),
                      ),
              icon: const Icon(Icons.undo),
              label: Text(s.undoLastWord),
            ),
          ],
        );
    }
  }

  String _exerciseInstruction(GrammarExercise exercise) =>
      widget.strings.isRussian
          ? exercise.instructionRu
          : exercise.instructionDe;

  String _wordOrderAnswer(GrammarExercise exercise) =>
      _wordOrderSelection.map((index) => exercise.options[index]).join(' ');

  Widget _paradigmFields(GrammarVerb verb) {
    final regular = verb.topicId == 'regular_present';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          verb.lemma,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        ...verb.forms.entries.map((entry) {
          final controller = _grammarControllers.putIfAbsent(
            entry.key,
            TextEditingController.new,
          );
          final expected =
              regular ? entry.value.substring(verb.stem.length) : entry.value;
          final correct = _grammarResults[entry.key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 92, child: Text(entry.key)),
                if (regular) Text(verb.stem),
                Expanded(
                  child: TextField(
                    key: Key('grammar-form-${entry.key}'),
                    controller: controller,
                    enabled: !_answered,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '_',
                      errorText:
                          _answered && correct == false ? expected : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _sessionCard(DailySession session) {
    final s = widget.strings;
    final status = switch (session.status) {
      DailySessionStatus.planned => s.planned,
      DailySessionStatus.inProgress => s.inProgress,
      DailySessionStatus.completed => s.completed,
    };
    final action = session.isComplete
        ? const Icon(Icons.check)
        : FilledButton(
            key: session.slot == 1
                ? const Key('start-review')
                : Key('start-review-${session.slot ?? session.id}'),
            onPressed: session.kind == DailySessionKind.grammar
                ? _availableGrammarTopics.isEmpty
                    ? null
                    : () => _selectSession(session)
                : _activeItems.isEmpty
                    ? null
                    : () => _selectSession(session),
            child: Text(
              session.status == DailySessionStatus.inProgress
                  ? s.continueSession
                  : s.start,
            ),
          );
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: session.isComplete
              ? const Icon(Icons.check)
              : Text('${session.slot ?? '+'}'),
        ),
        title: Text(
          session.slot == null
              ? s.extraSession
              : s.sessionNumber(session.slot!),
        ),
        subtitle: Text(
          '$status · ${s.sessionAnswers(session.answeredCount, session.targetAnswers)}',
        ),
        trailing: action,
      ),
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final items = await widget.learningItems.findActive();
    final grammarProgress = await widget.grammar.progress();
    final activeItemKeys = _activeItemKeys(items);
    final availableTopics = widget.grammarCatalog.availableTopicIds(
      learnedTopicIds: grammarProgress.values
          .where((entry) => entry.learned)
          .map((entry) => entry.topicId)
          .toSet(),
      activeItemKeys: activeItemKeys,
    );
    final sessions = await widget.sessions.ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
      includeGrammar: availableTopics.isNotEmpty,
    );
    if (!mounted) return;
    setState(() {
      _activeItems = items
          .where(
            (item) =>
                item.type == LearningItemType.word ||
                item.type == LearningItemType.noun ||
                item.type == LearningItemType.verb,
          )
          .toList(growable: false);
      _availableGrammarTopics = availableTopics;
      _daySessions = sessions;
      _session = null;
      _queue = const [];
      _grammarQueue = const [];
      _answered = false;
      _complete = false;
      _loading = false;
    });
  }

  Future<void> _selectSession(DailySession session) async {
    if (!session.isComplete) await _openSession(session.id);
  }

  Future<void> _createExtraSession() async {
    final extra = await widget.sessions.createExtra(
      localDate: localDayKey(DateTime.now()),
      now: DateTime.now().toUtc(),
    );
    await _openSession(extra.id);
  }

  Future<void> _openSession(String id) async {
    setState(() => _loading = true);
    final activeItems = await widget.learningItems.findActive();
    _activeItems = activeItems
        .where(
          (item) =>
              item.type == LearningItemType.word ||
              item.type == LearningItemType.noun ||
              item.type == LearningItemType.verb,
        )
        .toList(growable: false);
    var session = await widget.sessions.findById(id);
    if (session == null) {
      await _load();
      return;
    }
    if (session.isComplete) {
      session = await widget.sessions.createExtra(
        localDate: localDayKey(DateTime.now()),
        now: DateTime.now().toUtc(),
      );
    }
    if (session.kind == DailySessionKind.grammar) {
      await _openGrammarSession(session);
      return;
    }
    var queue = _itemsForIds(session.queueItemIds);
    if (session.status == DailySessionStatus.planned ||
        queue.length != session.remaining) {
      queue = await _buildQueue(
        length: session.remaining,
        previousItemId: session.lastItemId,
      );
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue.map((item) => item.id).toList(),
        now: DateTime.now().toUtc(),
      );
    }
    if (!mounted) return;
    final resolvedSession = session;
    setState(() {
      _session = resolvedSession;
      _queue = queue;
      _answered = false;
      _complete = resolvedSession.isComplete;
      _loading = false;
    });
    if (_queue.isNotEmpty) _answerFocus.requestFocus();
  }

  Future<void> _openGrammarSession(DailySession session) async {
    var queue =
        session.queueItemIds.where(_isValidGrammarTask).toList(growable: false);
    if (session.status == DailySessionStatus.planned ||
        queue.length != session.remaining) {
      queue = await _buildGrammarQueue(
        length: session.remaining,
        includeParadigm: session.answeredCount == 0,
      );
      if (queue.isNotEmpty) {
        session = await widget.sessions.start(
          id: session.id,
          queueItemIds: queue,
          now: DateTime.now().toUtc(),
        );
      }
    }
    if (!mounted) return;
    _clearGrammarInput();
    setState(() {
      _session = session;
      _grammarQueue = queue;
      _answered = false;
      _complete = session.isComplete;
      _loading = false;
    });
    if (queue.isNotEmpty && _paradigm(queue.first) == null) {
      _answerFocus.requestFocus();
    }
  }

  Future<List<String>> _buildGrammarQueue({
    required int length,
    required bool includeParadigm,
  }) async {
    if (length <= 0 || _availableGrammarTopics.isEmpty) return const [];
    final outcomes = await widget.grammar.recentOutcomes();
    final itemKeys = _activeItemKeys(_activeItems);
    final verbLemmas = _verbLemmas(_activeItems);
    final used = _daySessions.expand((session) => session.queueItemIds).toSet();
    final queue = <String>[];
    if (includeParadigm) {
      final conjugationTopics = _availableGrammarTopics
          .where(const {'regular_present', 'sein', 'haben'}.contains)
          .toList(growable: false);
      if (conjugationTopics.isNotEmpty) {
        final topicId = buildWeightedQueue(
          itemIds: conjugationTopics,
          recentOutcomes: outcomes,
          length: 1,
          random: _random,
        ).first;
        final verbs = widget.grammarCatalog.verbsFor(
          topicId: topicId,
          activeLemmas: verbLemmas,
        );
        if (verbs.isNotEmpty) {
          final verb = verbs[_random.nextInt(verbs.length)];
          queue.add('paradigm:$topicId:${verb.lemma}');
        }
      }
    }

    final topicPlan = buildWeightedQueue(
      itemIds: _availableGrammarTopics.toList(growable: false),
      recentOutcomes: outcomes,
      length: length - queue.length,
      random: _random,
    );
    for (final topicId in topicPlan) {
      final eligible = widget.grammarCatalog.exercisesFor(
        topicId: topicId,
        activeItemKeys: itemKeys,
      );
      var candidates = eligible
          .where(
            (exercise) =>
                !used.contains(exercise.id) && !queue.contains(exercise.id),
          )
          .toList(growable: true);
      if (candidates.isEmpty) candidates = [...eligible];
      if (candidates.isEmpty) continue;
      candidates.shuffle(_random);
      queue.add(candidates.first.id);
    }

    final allEligible = _availableGrammarTopics
        .expand(
          (topicId) => widget.grammarCatalog.exercisesFor(
            topicId: topicId,
            activeItemKeys: itemKeys,
          ),
        )
        .toList(growable: true)
      ..shuffle(_random);
    var fallbackIndex = 0;
    while (queue.length < length && allEligible.isNotEmpty) {
      queue.add(allEligible[fallbackIndex % allEligible.length].id);
      fallbackIndex++;
    }
    return queue;
  }

  bool _isValidGrammarTask(String id) {
    final paradigm = _paradigm(id);
    if (paradigm != null) return true;
    final exercise = widget.grammarCatalog.exercise(id);
    return exercise != null &&
        _availableGrammarTopics.contains(exercise.topicId) &&
        _activeItemKeys(_activeItems).contains(exercise.itemKey);
  }

  GrammarVerb? _paradigm(String id) {
    final parts = id.split(':');
    if (parts.length != 3 || parts.first != 'paradigm') return null;
    final verb = widget.grammarCatalog.verb(parts[2]);
    return verb?.topicId == parts[1] ? verb : null;
  }

  Set<String> _verbLemmas(List<LearningItem> items) => items
      .where((item) => item.type == LearningItemType.verb)
      .map(learningItemGerman)
      .map(GrammarCatalog.normalizeLemma)
      .toSet();

  Set<String> _activeItemKeys(List<LearningItem> items) => items
      .map(
        (item) => '${item.type.wireName}:'
            '${GrammarCatalog.normalizeLemma(learningItemGerman(item))}',
      )
      .toSet();

  List<LearningItem> _itemsForIds(List<String> ids) {
    final byId = {for (final item in _activeItems) item.id: item};
    return ids.map((id) => byId[id]).whereType<LearningItem>().toList();
  }

  Future<List<LearningItem>> _buildQueue({
    required int length,
    String? previousItemId,
    String? answeredItemId,
    bool? answerCorrect,
  }) async {
    final outcomes = await widget.practice.recentOutcomes();
    if (answeredItemId != null && answerCorrect != null) {
      final projected = <bool>[
        answerCorrect,
        ...outcomes[answeredItemId] ?? const <bool>[],
      ];
      outcomes[answeredItemId] = projected.take(10).toList(growable: false);
    }
    final ids = buildWeightedQueue(
      itemIds: _activeItems.map((item) => item.id).toList(growable: false),
      recentOutcomes: outcomes,
      length: length,
      random: _random,
      previousItemId: previousItemId,
    );
    return _itemsForIds(ids);
  }

  Future<void> _checkAnswer() async {
    if (_answered || _answerController.text.trim().isEmpty) return;
    final item = _current!;
    final correct = isPracticeAnswerCorrect(
      answer: _answerController.text,
      expected: learningItemGerman(item),
    );
    final nextQueue = await _buildQueue(
      length: _session!.remaining - 1,
      previousItemId: item.id,
      answeredItemId: item.id,
      answerCorrect: correct,
    );
    final updatedSession = await widget.sessions.recordAnswer(
      attempt: PracticeAttempt(
        id: newUuidV4(),
        itemId: item.id,
        sessionId: _session!.id,
        answerText: _answerController.text.trim(),
        correct: correct,
        attemptedAt: DateTime.now().toUtc(),
      ),
      remainingQueueItemIds:
          nextQueue.map((nextItem) => nextItem.id).toList(growable: false),
      now: DateTime.now().toUtc(),
    );
    widget.onAttemptSaved();
    if (!mounted) return;
    setState(() {
      _session = updatedSession;
      _nextQueue = nextQueue;
      _answered = true;
      _lastCorrect = correct;
    });
  }

  Future<void> _checkGrammar() async {
    if (_answered || _currentGrammar == null) return;
    final taskId = _currentGrammar!;
    final paradigm = _paradigm(taskId);
    final now = DateTime.now().toUtc();
    final attempts = <GrammarAttempt>[];
    final results = <String, bool>{};

    if (paradigm != null) {
      final regular = paradigm.topicId == 'regular_present';
      for (final entry in paradigm.forms.entries) {
        final answer = _grammarControllers[entry.key]?.text.trim() ?? '';
        if (answer.isEmpty) return;
        final expected =
            regular ? entry.value.substring(paradigm.stem.length) : entry.value;
        final correct = isPracticeAnswerCorrect(
          answer: answer,
          expected: expected,
        );
        results[entry.key] = correct;
        attempts.add(
          GrammarAttempt(
            id: newUuidV4(),
            topicId: paradigm.topicId,
            exerciseId: '$taskId:${entry.key}',
            sessionId: _session!.id,
            answerText: answer,
            correct: correct,
            attemptedAt: now,
          ),
        );
      }
    } else {
      final exercise = widget.grammarCatalog.exercise(taskId)!;
      final answer = switch (exercise.type) {
        GrammarExerciseType.text => _answerController.text.trim(),
        GrammarExerciseType.choice ||
        GrammarExerciseType.yesNo =>
          _selectedGrammarOption ?? '',
        GrammarExerciseType.wordOrder => _wordOrderAnswer(exercise),
      };
      if (answer.isEmpty) return;
      final correct = isPracticeAnswerCorrect(
        answer: answer,
        expected: exercise.answer,
      );
      results['answer'] = correct;
      attempts.add(
        GrammarAttempt(
          id: newUuidV4(),
          topicId: exercise.topicId,
          exerciseId: exercise.id,
          sessionId: _session!.id,
          answerText: answer,
          correct: correct,
          attemptedAt: now,
        ),
      );
    }

    final remaining = _grammarQueue.skip(1).toList(growable: false);
    final updated = await widget.sessions.recordGrammarTask(
      sessionId: _session!.id,
      attempts: attempts,
      remainingQueueItemIds: remaining,
      lastExerciseId: taskId,
      now: now,
    );
    widget.onAttemptSaved();
    if (!mounted) return;
    setState(() {
      _session = updated;
      _nextGrammarQueue = remaining;
      _grammarResults = results;
      _lastCorrect = results.values.every((value) => value);
      _answered = true;
    });
  }

  void _nextGrammar() {
    _clearGrammarInput();
    setState(() {
      _grammarQueue = _nextGrammarQueue;
      _nextGrammarQueue = const [];
      _grammarResults = const {};
      _answered = false;
      _complete = _session!.isComplete;
    });
    if (!_complete &&
        _grammarQueue.isNotEmpty &&
        _paradigm(_grammarQueue.first) == null) {
      _answerFocus.requestFocus();
    }
  }

  void _clearGrammarInput() {
    _answerController.clear();
    _selectedGrammarOption = null;
    _wordOrderSelection = const [];
    for (final controller in _grammarControllers.values) {
      controller.clear();
    }
  }

  void _next() {
    setState(() {
      _answerController.clear();
      _queue = _nextQueue;
      _nextQueue = const [];
      _answered = false;
      _complete = _session!.isComplete;
    });
    if (!_complete) _answerFocus.requestFocus();
  }
}

class _CenteredPanel extends StatelessWidget {
  const _CenteredPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

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
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
