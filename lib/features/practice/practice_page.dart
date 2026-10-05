import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../content/content_controller.dart';
import '../../domain/answer_checker.dart';
import '../../domain/app_settings.dart';
import '../../domain/daily_session.dart';
import '../../domain/grammar.dart';
import '../../domain/german_numbers.dart';
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

class PracticePage extends StatefulWidget {
  const PracticePage({
    required this.learningItems,
    required this.practice,
    required this.sessions,
    required this.grammar,
    required this.grammarCatalog,
    this.contentController,
    required this.strings,
    required this.refreshToken,
    required this.onAttemptSaved,
    this.requestedTopicId,
    this.practiceRequestRevision = 0,
    this.appSettings = const AppSettings(),
    super.key,
  });

  final LearningItemRepository learningItems;
  final PracticeRepository practice;
  final DailySessionRepository sessions;
  final GrammarRepository grammar;
  final GrammarCatalog grammarCatalog;
  final ContentController? contentController;
  final UiStrings strings;
  final int refreshToken;
  final VoidCallback onAttemptSaved;
  final String? requestedTopicId;
  final int practiceRequestRevision;
  final AppSettings appSettings;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  final _nextFocus = FocusNode(debugLabel: 'next-lesson-question');
  final _random = Random();
  List<LearningItem> _activeItems = const [];
  List<LearningItem> _queue = const [];
  List<DailySession> _daySessions = const [];
  List<String> _grammarQueue = const [];
  List<String> _nextGrammarQueue = const [];
  List<String> _numberQueue = const [];
  List<String> _nextNumberQueue = const [];
  Set<String> _availableGrammarTopics = const {};
  DailySession? _session;
  List<LearningItem> _nextQueue = const [];
  bool _loading = true;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _savingVocabularyAnswer = false;
  bool _unknownShortcutPending = false;
  bool _showVocabularyHelp = false;
  bool _complete = false;
  String? _pendingVocabularyAnswer;
  int _loadRevision = 0;
  String? _focusedGrammarTopicId;
  GrammarCatalog? _sessionCatalog;
  bool _sessionContentUnavailable = false;
  String? _unavailableSessionId;
  Map<String, bool> _grammarResults = const {};
  final Map<String, TextEditingController> _grammarControllers = {};
  String? _selectedGrammarOption;
  List<int> _wordOrderSelection = const [];

  LearningItem? get _current => _queue.isEmpty ? null : _queue.first;
  String? get _currentGrammar =>
      _grammarQueue.isEmpty ? null : _grammarQueue.first;
  String? get _currentNumber =>
      _numberQueue.isEmpty ? null : _numberQueue.first;
  GrammarCatalog get _catalog => _sessionCatalog ?? widget.grammarCatalog;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.grammarCatalog, oldWidget.grammarCatalog) &&
        _session == null) {
      _load();
    }
    if (widget.refreshToken != oldWidget.refreshToken && _session == null) {
      _load();
    }
    if (widget.practiceRequestRevision != oldWidget.practiceRequestRevision &&
        widget.requestedTopicId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startRequestedLesson(widget.requestedTopicId!);
      });
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
    _nextFocus.dispose();
    for (final controller in _grammarControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_sessionContentUnavailable) {
      return _CenteredPanel(
        icon: Icons.cloud_off_outlined,
        title: s.isRussian
            ? 'Версия урока недоступна'
            : 'Lektionsversion nicht verfügbar',
        message: s.isRussian
            ? 'Подключитесь к интернету и повторите попытку. '
                'Прогресс занятия сохранён.'
            : 'Bitte verbinden Sie sich mit dem Internet und versuchen Sie '
                'es erneut. Der Lernstand bleibt gespeichert.',
        action: FilledButton.icon(
          onPressed: _unavailableSessionId == null
              ? _load
              : () => _openSession(_unavailableSessionId!),
          icon: const Icon(Icons.refresh),
          label: Text(s.isRussian ? 'Повторить' : 'Erneut versuchen'),
        ),
      );
    }
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
      return _withUnknownShortcut(_grammarPractice());
    }
    if (_session!.kind == DailySessionKind.numbers) {
      return _withUnknownShortcut(_numberPractice());
    }

    final item = _current;
    if (item == null) {
      return _CenteredPanel(
        icon: Icons.school_outlined,
        title: s.learn,
        message: s.reviewEmpty,
      );
    }
    final toRussian = _session!.kind.isToRussian;
    final expected =
        toRussian ? learningItemMeaning(item) : learningItemGerman(item);
    final note = learningItemNote(item);
    final example = learningItemExample(item);
    final examples = example
        ?.split(';')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return _withUnknownShortcut(Center(
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
                      onPressed: _savingVocabularyAnswer ? null : _returnToPlan,
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
                    toRussian
                        ? learningItemGerman(item)
                        : learningItemMeaning(item),
                    key: const Key('practice-prompt'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (!_answered &&
                      toRussian &&
                      examples != null &&
                      examples.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    if (_showVocabularyHelp)
                      Semantics(
                        liveRegion: true,
                        child: Column(
                          key: const Key('vocabulary-help-examples'),
                          children: [
                            Text(
                              s.usageExamples,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            for (final value in examples)
                              Text(value, textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.center,
                        child: TextButton.icon(
                          key: const Key('vocabulary-help'),
                          onPressed: () => setState(
                            () => _showVocabularyHelp = true,
                          ),
                          icon: const Icon(Icons.lightbulb_outline),
                          label: Text(s.needHelp),
                        ),
                      ),
                  ],
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('practice-answer'),
                    controller: _answerController,
                    focusNode: _answerFocus,
                    enabled: !_answered && !_savingVocabularyAnswer,
                    decoration: InputDecoration(
                      labelText: toRussian ? s.russianAnswer : s.yourAnswer,
                    ),
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
                              if (toRussian &&
                                  _pendingVocabularyAnswer != null) ...[
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  key: const Key(
                                    'accept-russian-translation',
                                  ),
                                  onPressed: _savingVocabularyAnswer
                                      ? null
                                      : _acceptRussianTranslation,
                                  icon: _savingVocabularyAnswer
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.add, size: 18),
                                  label: Text(s.acceptMyTranslation),
                                ),
                              ],
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
                  if (_answered)
                    FilledButton(
                      key: const Key('next-answer'),
                      focusNode: _nextFocus,
                      onPressed: _savingVocabularyAnswer ? null : _next,
                      child: Text(s.next),
                    )
                  else ...[
                    FilledButton(
                      key: const Key('check-answer'),
                      onPressed: _savingVocabularyAnswer ? null : _checkAnswer,
                      child: Text(s.check),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('unknown-answer'),
                        onPressed:
                            _savingVocabularyAnswer ? null : _unknownAnswer,
                        child: Text(s.doNotKnow),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }

  Widget _withUnknownShortcut(Widget child) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape):
            _submitUnknownFromKeyboard,
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  void _submitUnknownFromKeyboard() {
    if (_answered ||
        _complete ||
        _unknownShortcutPending ||
        _savingVocabularyAnswer ||
        _session == null) {
      return;
    }
    _unknownShortcutPending = true;
    final submission = switch (_session!.kind) {
      DailySessionKind.grammar => _unknownGrammarAnswer(),
      DailySessionKind.numbers => _unknownNumber(),
      DailySessionKind.vocabularyToGerman ||
      DailySessionKind.vocabularyToRussian ||
      DailySessionKind.importantVocabularyToGerman ||
      DailySessionKind.importantVocabularyToRussian =>
        _unknownAnswer(),
    };
    submission.whenComplete(() => _unknownShortcutPending = false);
  }

  Widget _sessionSelection() {
    final s = widget.strings;
    final requiredSessions =
        _daySessions.where((session) => session.isRequired).toList();
    final toGermanSessions = requiredSessions
        .where((session) => session.kind == DailySessionKind.vocabularyToGerman)
        .toList();
    final toRussianSessions = requiredSessions
        .where(
            (session) => session.kind == DailySessionKind.vocabularyToRussian)
        .toList();
    final grammarSessions = requiredSessions
        .where((session) => session.kind == DailySessionKind.grammar)
        .toList();
    final numberSessions = requiredSessions
        .where((session) => session.kind == DailySessionKind.numbers)
        .toList();
    final extraToGerman = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.vocabularyToGerman)
        .toList();
    final extraToRussian = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.vocabularyToRussian)
        .toList();
    final extraGrammar = _daySessions
        .where((session) =>
            !session.isRequired && session.kind == DailySessionKind.grammar)
        .toList();
    final extraNumbers = _daySessions
        .where((session) =>
            !session.isRequired && session.kind == DailySessionKind.numbers)
        .toList();
    final importantToGerman = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.importantVocabularyToGerman)
        .toList();
    final importantToRussian = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.importantVocabularyToRussian)
        .toList();
    final importantItems =
        _activeItems.where((item) => item.isImportant).toList();
    final completed =
        requiredSessions.where((session) => session.isComplete).length;
    final toGermanComplete = toGermanSessions.isNotEmpty &&
        toGermanSessions.every((session) => session.isComplete);
    final toRussianComplete = toRussianSessions.isNotEmpty &&
        toRussianSessions.every((session) => session.isComplete);
    final grammarComplete = grammarSessions.isNotEmpty &&
        grammarSessions.every((session) => session.isComplete);
    final numbersComplete = numberSessions.isNotEmpty &&
        numberSessions.every((session) => session.isComplete);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.dailyPlan, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.dailyProgress(completed, requiredSessions.length)),
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
        const SizedBox(height: 16),
        _sessionCategory(
          kind: DailySessionKind.vocabularyToGerman,
          icon: Icons.arrow_forward,
          title: s.toGermanCategory,
          sessions: [...toGermanSessions, ...extraToGerman],
          canAdd: toGermanComplete,
          addKey: const Key('create-extra-session'),
          onAdd: () => _createExtraSession(DailySessionKind.vocabularyToGerman),
        ),
        const SizedBox(height: 20),
        _sessionCategory(
          kind: DailySessionKind.vocabularyToRussian,
          icon: Icons.arrow_back,
          title: s.toRussianCategory,
          sessions: [...toRussianSessions, ...extraToRussian],
          canAdd: toRussianComplete,
          addKey: const Key('create-extra-to-russian-session'),
          onAdd: () =>
              _createExtraSession(DailySessionKind.vocabularyToRussian),
        ),
        if (widget.appSettings.includeImportantLessons) ...[
          const SizedBox(height: 20),
          Text(
            s.importantWordsCategory,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (importantItems.isEmpty &&
              importantToGerman.every((session) => session.isComplete) &&
              importantToRussian.every((session) => session.isComplete)) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.star_outline),
                title: Text(s.noImportantWordsHint),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _sessionCategory(
            kind: DailySessionKind.importantVocabularyToGerman,
            icon: Icons.star,
            title: s.importantToGermanCategory,
            sessions: importantToGerman,
            canAdd: true,
            canStart: importantItems.isNotEmpty,
            addKey: const Key('create-important-to-german-session'),
            onAdd: () => _createExtraSession(
              DailySessionKind.importantVocabularyToGerman,
            ),
          ),
          const SizedBox(height: 12),
          _sessionCategory(
            kind: DailySessionKind.importantVocabularyToRussian,
            icon: Icons.star_border,
            title: s.importantToRussianCategory,
            sessions: importantToRussian,
            canAdd: true,
            canStart: importantItems.isNotEmpty,
            addKey: const Key('create-important-to-russian-session'),
            onAdd: () => _createExtraSession(
              DailySessionKind.importantVocabularyToRussian,
            ),
          ),
        ],
        const SizedBox(height: 20),
        _sessionCategory(
          kind: DailySessionKind.numbers,
          icon: Icons.pin_outlined,
          title: s.numbersCategory,
          sessions: [...numberSessions, ...extraNumbers],
          canAdd: numbersComplete,
          addKey: const Key('create-extra-number-session'),
          onAdd: () => _createExtraSession(DailySessionKind.numbers),
        ),
        if (grammarSessions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sessionCategory(
            kind: DailySessionKind.grammar,
            icon: Icons.school_outlined,
            title: s.grammarCategory,
            sessions: [...grammarSessions, ...extraGrammar],
            canAdd: grammarComplete,
            addKey: const Key('create-extra-grammar-session'),
            onAdd: () => _createExtraSession(DailySessionKind.grammar),
          ),
        ],
      ],
    );
  }

  Widget _sessionCategory({
    required DailySessionKind kind,
    required IconData icon,
    required String title,
    required List<DailySession> sessions,
    required bool canAdd,
    bool canStart = true,
    required Key addKey,
    required VoidCallback onAdd,
  }) {
    final completed = sessions.where((session) => session.isComplete).length;
    final inProgress = sessions
        .where((session) => session.status == DailySessionStatus.inProgress)
        .firstOrNull;
    final next = sessions
        .where((session) => session.status == DailySessionStatus.planned)
        .firstOrNull;
    final actionSession = inProgress ?? next;
    final actionEnabled = inProgress != null
        ? _canOpenSession(inProgress)
        : canAdd
            ? canStart
            : actionSession != null && _canOpenSession(actionSession);
    final actionLabel = inProgress != null
        ? widget.strings.continueLesson
        : canAdd
            ? sessions.isEmpty
                ? widget.strings.start
                : widget.strings.addLesson
            : widget.strings.nextLesson;
    final actionIcon = inProgress != null
        ? Icons.play_arrow
        : canAdd
            ? Icons.add
            : Icons.skip_next;
    final categoryKey = kind.wireName.replaceAll('_', '-');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
            child: Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        widget.strings.categoryProgress(
                          completed,
                          sessions.length,
                        ),
                        key: Key('session-category-progress-$categoryKey'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (inProgress != null)
                        Text(
                          widget.strings.sessionAnswers(
                            inProgress.answeredCount,
                            inProgress.targetAnswers,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: canAdd && inProgress == null
                      ? addKey
                      : Key('session-category-action-$categoryKey'),
                  onPressed: actionEnabled
                      ? () {
                          if (inProgress != null) {
                            _selectSession(inProgress);
                          } else if (canAdd) {
                            onAdd();
                          } else if (next != null) {
                            _selectSession(next);
                          }
                        }
                      : null,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel),
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  bool _canOpenSession(DailySession session) => switch (session.kind) {
        DailySessionKind.grammar =>
          _availableGrammarTopics.isNotEmpty || session.queueItemIds.isNotEmpty,
        DailySessionKind.numbers => true,
        DailySessionKind.importantVocabularyToGerman ||
        DailySessionKind.importantVocabularyToRussian =>
          session.queueItemIds.isNotEmpty ||
              _activeItems.any((item) => item.isImportant),
        _ => _activeItems.isNotEmpty,
      };

  Widget _numberPractice() {
    final s = widget.strings;
    final taskId = _currentNumber;
    if (taskId == null) {
      return _CenteredPanel(
        icon: Icons.pin_outlined,
        title: s.numbersCategory,
        message: s.grammarSessionUnavailable,
        action: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.arrow_back),
          label: Text(s.dailyPlan),
        ),
      );
    }
    final task = _numberTask(taskId);
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
                  Text(
                    s.progress(
                      _session!.answeredCount,
                      _session!.targetAnswers,
                    ),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    task.$1,
                    key: const Key('number-prompt'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    key: const Key('number-answer'),
                    controller: _answerController,
                    focusNode: _answerFocus,
                    enabled: !_answered,
                    keyboardType:
                        task.$3 ? TextInputType.number : TextInputType.text,
                    decoration: InputDecoration(
                      labelText:
                          task.$3 ? s.digitsAnswer : s.germanNumberAnswer,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _answered ? null : _checkNumber(),
                  ),
                  if (_answered) ...[
                    const SizedBox(height: 20),
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
                          if (!_lastCorrect) Text(s.correctAnswer(task.$2)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_answered)
                    FilledButton(
                      key: const Key('next-number-answer'),
                      focusNode: _nextFocus,
                      onPressed: _nextNumber,
                      child: Text(s.next),
                    )
                  else ...[
                    FilledButton(
                      key: const Key('check-number-answer'),
                      onPressed: _checkNumber,
                      child: Text(s.check),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('unknown-number-answer'),
                        onPressed: _unknownNumber,
                        child: Text(s.doNotKnow),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
    final exercise = paradigm == null ? _catalog.exercise(taskId) : null;
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
                  if (_answered)
                    FilledButton(
                      key: const Key('next-grammar-answer'),
                      focusNode: _nextFocus,
                      onPressed: _nextGrammar,
                      child: Text(s.next),
                    )
                  else ...[
                    FilledButton(
                      key: const Key('check-grammar-answer'),
                      onPressed: _checkGrammar,
                      child: Text(s.check),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: const Key('unknown-grammar-answer'),
                        onPressed: _unknownGrammarAnswer,
                        child: Text(s.doNotKnow),
                      ),
                    ),
                  ],
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
                      label: Text(_optionLabel(option)),
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
          ? exercise.instructionRu.isEmpty
              ? widget.strings.fillMissingPart
              : exercise.instructionRu
          : exercise.instructionDe;

  String _optionLabel(String option) {
    if (!widget.strings.isRussian) return option;
    return const {
          'Ja': 'Да',
          'Nein': 'Нет',
          'Verb': 'Глагол',
          'Nomen': 'Существительное',
          'Adjektiv': 'Прилагательное',
          'Adverb': 'Наречие',
          'Präposition': 'Предлог',
          'Nominativ': 'Именительный падеж',
          'Akkusativ': 'Винительный падеж',
          'Frage': 'Вопрос',
          'ein Nomen': 'существительное',
          'einen Umstand': 'обстоятельство',
          'Mit wem': 'С кем',
          'Wann': 'Когда',
          'Was': 'Что',
          'Wen': 'Кого',
          'Wer': 'Кто',
          'Wie': 'Как',
          'Wo': 'Где',
          'Woher': 'Откуда',
        }[option] ??
        option;
  }

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
        ...verb.forms.entries.indexed.map((indexedEntry) {
          final index = indexedEntry.$1;
          final entry = indexedEntry.$2;
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
                    focusNode: index == 0 ? _answerFocus : null,
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

  Future<void> _load() async {
    final revision = ++_loadRevision;
    if (_daySessions.isEmpty && mounted) setState(() => _loading = true);
    _sessionCatalog = null;
    _sessionContentUnavailable = false;
    _unavailableSessionId = null;
    final now = DateTime.now();
    final items = await widget.learningItems.findActive();
    final grammarProgress = await widget.grammar.progress();
    final activeItemKeys = _activeItemKeys(items);
    final availableTopics = _catalog.availableTopicIds(
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
    if (!mounted || revision != _loadRevision) return;
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
      _numberQueue = const [];
      _focusedGrammarTopicId = null;
      _answered = false;
      _showVocabularyHelp = false;
      _pendingVocabularyAnswer = null;
      _savingVocabularyAnswer = false;
      _complete = false;
      _loading = false;
    });
  }

  Future<void> _selectSession(DailySession session) async {
    if (!session.isComplete) await _openSession(session.id);
  }

  Future<void> _createExtraSession(DailySessionKind kind) async {
    final extra = await widget.sessions.createExtra(
      localDate: localDayKey(DateTime.now()),
      now: DateTime.now().toUtc(),
      kind: kind,
    );
    await _openSession(extra.id);
  }

  Future<void> _startRequestedLesson(String topicId) async {
    if (topicId == 'numbers') {
      await _createExtraSession(DailySessionKind.numbers);
      return;
    }
    setState(() => _loading = true);
    final items = await widget.learningItems.findActive();
    final progress = await widget.grammar.progress();
    final availableTopics = _catalog.availableTopicIds(
      learnedTopicIds: progress.values
          .where((entry) => entry.learned)
          .map((entry) => entry.topicId)
          .toSet(),
      activeItemKeys: _activeItemKeys(items),
    );
    if (!mounted) return;
    _activeItems = items;
    _availableGrammarTopics = availableTopics;
    if (!availableTopics.contains(topicId)) {
      await _load();
      return;
    }
    _focusedGrammarTopicId = topicId;
    await _createExtraSession(DailySessionKind.grammar);
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
        kind: session.kind,
      );
    }
    if (session.kind == DailySessionKind.grammar) {
      final catalog = await _catalogForSession(session);
      if (!mounted) return;
      if (catalog == null) {
        setState(() {
          _sessionContentUnavailable = true;
          _unavailableSessionId = session!.id;
          _loading = false;
        });
        return;
      }
      _sessionCatalog = catalog;
      await _openGrammarSession(session);
      return;
    }
    if (session.kind == DailySessionKind.numbers) {
      await _openNumberSession(session);
      return;
    }
    var queue = _itemsForIds(session.queueItemIds);
    if (session.status == DailySessionStatus.planned ||
        queue.length != session.remaining) {
      queue = await _buildQueue(
        length: session.remaining,
        previousItemId: session.lastItemId,
        items: session.kind.isImportantVocabulary
            ? _activeItems.where((item) => item.isImportant).toList()
            : null,
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
      _showVocabularyHelp = false;
      _pendingVocabularyAnswer = null;
      _savingVocabularyAnswer = false;
      _complete = resolvedSession.isComplete;
      _loading = false;
    });
    if (_queue.isNotEmpty) _focusAnswerField();
  }

  Future<GrammarCatalog?> _catalogForSession(DailySession session) async {
    if (session.status == DailySessionStatus.planned ||
        session.contentVersion == widget.grammarCatalog.contentVersion) {
      return widget.grammarCatalog;
    }
    return widget.contentController?.catalogForVersion(
      session.contentVersion,
    );
  }

  Future<void> _openNumberSession(DailySession session) async {
    var queue =
        session.queueItemIds.where(_isValidNumberTask).toList(growable: false);
    if (session.status == DailySessionStatus.planned ||
        queue.length != session.remaining) {
      queue = _buildNumberQueue(session.remaining);
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue,
        now: DateTime.now().toUtc(),
      );
    }
    if (!mounted) return;
    _answerController.clear();
    setState(() {
      _session = session;
      _numberQueue = queue;
      _answered = false;
      _complete = session.isComplete;
      _loading = false;
    });
    if (queue.isNotEmpty) _focusAnswerField();
  }

  List<String> _buildNumberQueue(int length) {
    final values = List<int>.generate(101, (index) => index)..shuffle(_random);
    final completeSet = values
        .expand(
          (value) => [
            'number:to_digits:$value',
            'number:to_german:$value',
          ],
        )
        .toList(growable: false);
    return List<String>.generate(
      length,
      (index) => completeSet[index % completeSet.length],
      growable: false,
    );
  }

  bool _isValidNumberTask(String id) {
    final parts = id.split(':');
    if (parts.length != 3 || parts.first != 'number') return false;
    if (parts[1] != 'to_digits' && parts[1] != 'to_german') return false;
    final value = int.tryParse(parts[2]);
    return value != null && value >= 0 && value <= 100;
  }

  (String, String, bool) _numberTask(String id) {
    final parts = id.split(':');
    final value = int.parse(parts[2]);
    final toDigits = parts[1] == 'to_digits';
    return toDigits
        ? (germanNumberWord(value), '$value', true)
        : ('$value', germanNumberWord(value), false);
  }

  Future<void> _openGrammarSession(DailySession session) async {
    var queue = session.queueItemIds
        .where(
          session.status == DailySessionStatus.planned
              ? _isValidGrammarTask
              : _grammarTaskExists,
        )
        .toList(growable: false);
    if (session.status == DailySessionStatus.planned ||
        queue.length != session.remaining) {
      queue = await _buildGrammarQueue(
        length: session.remaining,
        includeParadigm: session.answeredCount == 0,
        topicId: _focusedGrammarTopicId,
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
    if (queue.isNotEmpty) _focusAnswerField();
  }

  Future<List<String>> _buildGrammarQueue({
    required int length,
    required bool includeParadigm,
    String? topicId,
  }) async {
    if (length <= 0 || _availableGrammarTopics.isEmpty) return const [];
    final topicIds = topicId == null
        ? _availableGrammarTopics
        : _availableGrammarTopics.where((id) => id == topicId).toSet();
    if (topicIds.isEmpty) return const [];
    final outcomes = await widget.grammar.recentOutcomes();
    final itemKeys = _activeItemKeys(_activeItems);
    final verbLemmas = _verbLemmas(_activeItems);
    final used = _daySessions.expand((session) => session.queueItemIds).toSet();
    final queue = <String>[];
    if (includeParadigm) {
      final conjugationTopics = topicIds
          .where(const {'regular_present', 'sein', 'haben'}.contains)
          .toList(growable: false);
      if (conjugationTopics.isNotEmpty) {
        final topicId = buildWeightedQueue(
          itemIds: conjugationTopics,
          recentOutcomes: outcomes,
          length: 1,
          random: _random,
        ).first;
        final verbs = _catalog.verbsFor(
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
      itemIds: topicIds.toList(growable: false),
      recentOutcomes: outcomes,
      length: length - queue.length,
      random: _random,
    );
    for (final topicId in topicPlan) {
      final eligible = _catalog.exercisesFor(
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

    final allEligible = topicIds
        .expand(
          (topicId) => _catalog.exercisesFor(
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
    final exercise = _catalog.exercise(id);
    return exercise != null &&
        _availableGrammarTopics.contains(exercise.topicId) &&
        (exercise.requiredItemType == 'none' ||
            _activeItemKeys(_activeItems).contains(exercise.itemKey));
  }

  bool _grammarTaskExists(String id) =>
      _paradigm(id) != null || _catalog.exercise(id) != null;

  GrammarVerb? _paradigm(String id) {
    final parts = id.split(':');
    if (parts.length != 3 || parts.first != 'paradigm') return null;
    final verb = _catalog.verb(parts[2]);
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
    List<LearningItem>? items,
  }) async {
    final outcomes = await widget.practice.recentOutcomes();
    final candidates = items ?? _activeItems;
    final ids = buildWeightedQueue(
      itemIds: candidates.map((item) => item.id).toList(growable: false),
      recentOutcomes: outcomes,
      length: length,
      random: _random,
      maxWeight: widget.appSettings.problemWordMaxWeight,
      previousItemId: previousItemId,
    );
    final byId = {for (final item in candidates) item.id: item};
    return ids.map((id) => byId[id]).whereType<LearningItem>().toList();
  }

  Future<void> _checkAnswer() async {
    if (_answered || _answerController.text.trim().isEmpty) return;
    await _submitAnswer(_answerController.text.trim());
  }

  Future<void> _unknownAnswer() => _submitAnswer('');

  Future<void> _submitAnswer(String answer) async {
    if (_answered || _savingVocabularyAnswer || _current == null) return;
    final item = _current!;
    final toRussian = _session!.kind.isToRussian;
    final correct = toRussian
        ? isAnyPracticeAnswerCorrect(
            answer: answer,
            expectedAlternatives: learningItemMeaning(item),
          )
        : isPracticeAnswerCorrect(
            answer: answer,
            expected: learningItemGerman(item),
          );

    if (toRussian && !correct && answer.isNotEmpty && !answer.contains(';')) {
      setState(() {
        _answered = true;
        _lastCorrect = false;
        _pendingVocabularyAnswer = answer;
      });
      _focusNextButton();
      return;
    }

    setState(() => _savingVocabularyAnswer = true);
    try {
      final result = await _recordVocabularyAnswer(
        item: item,
        answer: answer,
        correct: correct,
      );
      if (!mounted) return;
      setState(() {
        _session = result.$1;
        _nextQueue = result.$2;
        _answered = true;
        _lastCorrect = correct;
        _pendingVocabularyAnswer = null;
        _savingVocabularyAnswer = false;
      });
      _focusNextButton();
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingVocabularyAnswer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.answerSaveFailed)),
      );
    }
  }

  Future<(DailySession, List<LearningItem>)> _recordVocabularyAnswer({
    required LearningItem item,
    required String answer,
    required bool correct,
  }) async {
    final nextQueue = _queue.skip(1).toList(growable: false);
    final updatedSession = await widget.sessions.recordAnswer(
      attempt: PracticeAttempt(
        id: newUuidV4(),
        itemId: item.id,
        sessionId: _session!.id,
        answerText: answer,
        correct: correct,
        attemptedAt: DateTime.now().toUtc(),
      ),
      remainingQueueItemIds:
          nextQueue.map((nextItem) => nextItem.id).toList(growable: false),
      now: DateTime.now().toUtc(),
    );
    widget.onAttemptSaved();
    return (updatedSession, nextQueue);
  }

  Future<void> _acceptRussianTranslation() async {
    final answer = _pendingVocabularyAnswer;
    final item = _current;
    if (answer == null || item == null || _savingVocabularyAnswer) return;

    setState(() => _savingVocabularyAnswer = true);
    try {
      final currentTime = DateTime.now().toUtc();
      final updatedAt =
          currentTime.isBefore(item.createdAt) ? item.createdAt : currentTime;
      final updatedItem = LearningItem(
        id: item.id,
        type: item.type,
        level: item.level,
        lesson: item.lesson,
        topic: item.topic,
        learned: item.learned,
        createdAt: item.createdAt,
        updatedAt: updatedAt,
        deletedAt: item.deletedAt,
        sourceRef: item.sourceRef,
        content: {
          ...item.content,
          'translation_ru': appendRussianPracticeAnswerAlternative(
            expectedAlternatives: learningItemMeaning(item),
            answer: answer,
          ),
        },
      );
      await widget.learningItems.save(updatedItem);
      _replaceActiveItem(updatedItem);
      final result = await _recordVocabularyAnswer(
        item: updatedItem,
        answer: answer,
        correct: true,
      );
      if (!mounted) return;
      setState(() {
        _session = result.$1;
        _nextQueue = result.$2;
        _lastCorrect = true;
        _pendingVocabularyAnswer = null;
        _savingVocabularyAnswer = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.translationAdded)),
      );
      _focusNextButton();
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingVocabularyAnswer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.translationAddFailed)),
      );
    }
  }

  void _replaceActiveItem(LearningItem replacement) {
    _activeItems = [
      for (final item in _activeItems)
        if (item.id == replacement.id) replacement else item,
    ];
    _queue = [
      for (final item in _queue)
        if (item.id == replacement.id) replacement else item,
    ];
  }

  Future<void> _checkNumber() async {
    if (_answered || _answerController.text.trim().isEmpty) return;
    await _submitNumber(_answerController.text.trim());
  }

  Future<void> _unknownNumber() => _submitNumber('');

  Future<void> _submitNumber(String answer) async {
    final taskId = _currentNumber;
    if (_answered || taskId == null) return;
    final task = _numberTask(taskId);
    final value = int.parse(taskId.split(':').last);
    final correct = value == 100 && taskId.contains(':to_german:')
        ? isAnyPracticeAnswerCorrect(
            answer: answer,
            expectedAlternatives: 'hundert;einhundert',
          )
        : isPracticeAnswerCorrect(answer: answer, expected: task.$2);
    final remaining = _numberQueue.skip(1).toList(growable: false);
    final updated = await widget.sessions.recordGrammarTask(
      sessionId: _session!.id,
      attempts: [
        GrammarAttempt(
          id: newUuidV4(),
          topicId: 'numbers',
          exerciseId: taskId,
          sessionId: _session!.id,
          answerText: answer,
          correct: correct,
          attemptedAt: DateTime.now().toUtc(),
        ),
      ],
      remainingQueueItemIds: remaining,
      lastExerciseId: taskId,
      now: DateTime.now().toUtc(),
    );
    widget.onAttemptSaved();
    if (!mounted) return;
    setState(() {
      _session = updated;
      _nextNumberQueue = remaining;
      _lastCorrect = correct;
      _answered = true;
    });
    _focusNextButton();
  }

  Future<void> _checkGrammar() => _submitGrammar(allowEmpty: false);

  Future<void> _unknownGrammarAnswer() => _submitGrammar(allowEmpty: true);

  Future<void> _submitGrammar({required bool allowEmpty}) async {
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
        if (answer.isEmpty && !allowEmpty) return;
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
      final exercise = _catalog.exercise(taskId)!;
      final answer = switch (exercise.type) {
        GrammarExerciseType.text => _answerController.text.trim(),
        GrammarExerciseType.choice ||
        GrammarExerciseType.yesNo =>
          _selectedGrammarOption ?? '',
        GrammarExerciseType.wordOrder => _wordOrderAnswer(exercise),
      };
      if (answer.isEmpty && !allowEmpty) return;
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
    _focusNextButton();
  }

  void _focusNextButton() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _answered) _nextFocus.requestFocus();
    });
  }

  void _focusAnswerField() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_answered && !_complete) _answerFocus.requestFocus();
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
    if (!_complete && _grammarQueue.isNotEmpty) _focusAnswerField();
  }

  void _nextNumber() {
    setState(() {
      _answerController.clear();
      _numberQueue = _nextNumberQueue;
      _nextNumberQueue = const [];
      _answered = false;
      _complete = _session!.isComplete;
    });
    if (!_complete) _focusAnswerField();
  }

  void _clearGrammarInput() {
    _answerController.clear();
    _selectedGrammarOption = null;
    _wordOrderSelection = const [];
    for (final controller in _grammarControllers.values) {
      controller.clear();
    }
  }

  Future<void> _returnToPlan() async {
    if (!await _recordPendingVocabularyError()) return;
    await _load();
  }

  Future<void> _next() async {
    if (!await _recordPendingVocabularyError()) return;
    setState(() {
      _answerController.clear();
      _queue = _nextQueue;
      _nextQueue = const [];
      _answered = false;
      _pendingVocabularyAnswer = null;
      _showVocabularyHelp = false;
      _complete = _session!.isComplete;
    });
    if (!_complete) _focusAnswerField();
  }

  Future<bool> _recordPendingVocabularyError() async {
    final answer = _pendingVocabularyAnswer;
    final item = _current;
    if (answer == null || item == null) return true;
    setState(() => _savingVocabularyAnswer = true);
    try {
      final result = await _recordVocabularyAnswer(
        item: item,
        answer: answer,
        correct: false,
      );
      if (!mounted) return false;
      setState(() {
        _session = result.$1;
        _nextQueue = result.$2;
        _pendingVocabularyAnswer = null;
        _savingVocabularyAnswer = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() => _savingVocabularyAnswer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.answerSaveFailed)),
      );
      return false;
    }
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
