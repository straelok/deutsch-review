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
import '../../ui/responsive.dart';

enum _LessonGroup { toGerman, toRussian, grammar, other }

const _irregularVerbTopicId = 'irregular_verb_forms';

EdgeInsets _practiceCardPadding(BuildContext context) {
  return EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 20 : 28);
}

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
  List<DailySession> _persistentSessions = const [];
  List<String> _grammarQueue = const [];
  List<String> _nextGrammarQueue = const [];
  List<String> _numberQueue = const [];
  List<String> _nextNumberQueue = const [];
  List<LearningItem> _matchingBoard = const [];
  Set<String> _matchedItemIds = const {};
  Set<String> _matchingFailedItemIds = const {};
  String? _selectedMatchingItemId;
  (String, String)? _wrongMatchingPair;
  List<String> _matchingRussianOrder = const [];
  List<LearningItem> _choiceOptions = const [];
  String? _selectedChoiceItemId;
  bool _choiceToRussian = true;
  Set<String> _availableGrammarTopics = const {};
  Set<String> _favoriteGrammarTopics = const {};
  DailySession? _session;
  List<LearningItem> _nextQueue = const [];
  bool _loading = true;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _savingVocabularyAnswer = false;
  bool _unknownShortcutPending = false;
  bool _showVocabularyHelp = false;
  bool _isCorrection = false;
  bool _complete = false;
  String? _pendingVocabularyAnswer;
  int _loadRevision = 0;
  String? _focusedGrammarTopicId;
  GrammarCatalog? _sessionCatalog;
  bool _sessionContentUnavailable = false;
  String? _unavailableSessionId;
  Map<String, bool> _grammarResults = const {};
  Set<String> _grammarCorrectionKeys = const {};
  final Map<String, TextEditingController> _grammarControllers = {};
  String? _selectedGrammarOption;
  List<int> _wordOrderSelection = const [];
  final Set<_LessonGroup> _expandedLessonGroups = <_LessonGroup>{};

  LearningItem? get _current => _queue.isEmpty ? null : _queue.first;
  String? get _currentGrammar =>
      _grammarQueue.isEmpty ? null : _grammarQueue.first;
  String? get _currentNumber =>
      _numberQueue.isEmpty ? null : _numberQueue.first;
  GrammarCatalog get _catalog => _sessionCatalog ?? widget.grammarCatalog;
  bool get _repeatIncorrectImmediately =>
      widget.appSettings.repeatIncorrectImmediately;

  Set<String> get _standardGrammarTopicIds => _availableGrammarTopics
      .where(
        (id) =>
            _catalog.topics
                .where((topic) => topic.id == id)
                .firstOrNull
                ?.practiceSection ==
            'grammar',
      )
      .toSet();

  List<GrammarExercise> get _irregularVerbExercises => _catalog.exercisesFor(
        topicId: _irregularVerbTopicId,
        activeItemKeys: _activeItemKeys(_activeItems),
      );

  String _progressLabel() {
    final progress = widget.strings.progress(
      _isCorrection
          ? max(0, _session!.answeredCount - 1)
          : _session!.answeredCount,
      _session!.targetAnswers,
    );
    return _isCorrection
        ? widget.strings.correctionProgress(progress)
        : progress;
  }

  List<T> _withDelayedControl<T>(List<T> remaining, T item) {
    final result = remaining.toList(growable: true);
    final delay = min(result.length, 3 + _random.nextInt(3));
    result.insert(delay, item);
    return result;
  }

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
          key: const Key('completed-session-back-to-plan'),
          onPressed: _load,
          icon: const Icon(Icons.today_outlined),
          label: Text(s.dailyPlan),
        ),
      );
    }

    if (_session!.kind.isGrammar) {
      return _withUnknownShortcut(_grammarPractice());
    }
    if (_session!.kind == DailySessionKind.numbers) {
      return _withUnknownShortcut(_numberPractice());
    }
    if (_session!.kind == DailySessionKind.matching ||
        _session!.kind == DailySessionKind.importantMatching) {
      return _matchingPractice();
    }
    if (_session!.kind == DailySessionKind.multipleChoice) {
      return _withMultipleChoiceShortcuts(_multipleChoicePractice());
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
        padding: AppLayout.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: _practiceCardPadding(context),
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
                    _progressLabel(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    toRussian
                        ? learningItemGermanWithPlural(item)
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
                            if (_lastCorrect && toRussian) ...[
                              const SizedBox(height: 6),
                              Text(
                                s.allTranslations(expected),
                                key: const Key('all-translations'),
                              ),
                            ],
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
                      child: Text(
                        _repeatIncorrectImmediately && !_lastCorrect
                            ? s.tryAgain
                            : s.next,
                      ),
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
      DailySessionKind.grammar ||
      DailySessionKind.favoriteGrammar =>
        _unknownGrammarAnswer(),
      DailySessionKind.numbers => _unknownNumber(),
      DailySessionKind.matching ||
      DailySessionKind.importantMatching =>
        Future<void>.value(),
      DailySessionKind.multipleChoice => _answerMultipleChoice(null),
      DailySessionKind.marathonToGerman ||
      DailySessionKind.marathonToRussian =>
        _unknownAnswer(),
      DailySessionKind.vocabularyToGerman ||
      DailySessionKind.easyVocabularyToGerman ||
      DailySessionKind.vocabularyToRussian ||
      DailySessionKind.importantVocabularyToGerman ||
      DailySessionKind.importantEasyVocabularyToGerman ||
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
        .where((session) =>
            session.kind == DailySessionKind.grammar &&
            !_isTopicSession(session, _irregularVerbTopicId))
        .toList();
    final irregularVerbSessions = _daySessions
        .where((session) =>
            session.kind == DailySessionKind.grammar &&
            _isTopicSession(session, _irregularVerbTopicId))
        .toList();
    final numberSessions = requiredSessions
        .where((session) => session.kind == DailySessionKind.numbers)
        .toList();
    final extraToGerman = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.vocabularyToGerman)
        .toList();
    final legacyEasyToGerman = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.easyVocabularyToGerman)
        .toList();
    final extraToRussian = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.vocabularyToRussian)
        .toList();
    final extraGrammar = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.grammar &&
            !_isTopicSession(session, _irregularVerbTopicId))
        .toList();
    final favoriteGrammar = _daySessions
        .where((session) => session.kind == DailySessionKind.favoriteGrammar)
        .toList();
    final extraNumbers = _daySessions
        .where((session) =>
            !session.isRequired && session.kind == DailySessionKind.numbers)
        .toList();
    final matchingSessions = _daySessions
        .where((session) => session.kind == DailySessionKind.matching)
        .toList();
    final importantMatchingSessions = _daySessions
        .where((session) => session.kind == DailySessionKind.importantMatching)
        .toList();
    final multipleChoiceSessions = _daySessions
        .where((session) => session.kind == DailySessionKind.multipleChoice)
        .toList();
    final marathonToGerman = _persistentSessions
        .where((session) => session.kind == DailySessionKind.marathonToGerman)
        .firstOrNull;
    final marathonToRussian = _persistentSessions
        .where((session) => session.kind == DailySessionKind.marathonToRussian)
        .firstOrNull;
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
    final legacyImportantEasyToGerman = _daySessions
        .where((session) =>
            !session.isRequired &&
            session.kind == DailySessionKind.importantEasyVocabularyToGerman)
        .toList();
    final importantItems =
        _activeItems.where((item) => item.isImportant).toList();
    final toGermanComplete = toGermanSessions.isNotEmpty &&
        toGermanSessions.every((session) => session.isComplete);
    final toRussianComplete = toRussianSessions.isNotEmpty &&
        toRussianSessions.every((session) => session.isComplete);
    final grammarComplete = grammarSessions.isNotEmpty &&
        grammarSessions.every((session) => session.isComplete);
    final numbersComplete = numberSessions.isNotEmpty &&
        numberSessions.every((session) => session.isComplete);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppLayout.contentMaxWidth),
        child: ListView(
          padding: AppLayout.pagePadding(context),
          children: [
            Text(s.dailyPlan,
                style: Theme.of(context).textTheme.headlineMedium),
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
            _lessonGroup(
              group: _LessonGroup.toGerman,
              icon: Icons.arrow_forward,
              title: s.toGermanCategory,
              sessions: [
                ...toGermanSessions,
                ...extraToGerman,
                ...legacyEasyToGerman,
                ...importantToGerman,
                ...legacyImportantEasyToGerman,
                if (marathonToGerman != null) marathonToGerman,
              ],
              children: [
                _sessionCategory(
                  kind: DailySessionKind.vocabularyToGerman,
                  icon: Icons.arrow_forward,
                  title: s.standardMode,
                  sessions: [
                    ...toGermanSessions,
                    ...extraToGerman,
                    ...legacyEasyToGerman,
                  ],
                  canAdd: toGermanComplete || toGermanSessions.isEmpty,
                  addKey: const Key('create-extra-session'),
                  onAdd: () =>
                      _createExtraSession(DailySessionKind.vocabularyToGerman),
                  secondaryAction: _SessionSecondaryAction(
                    sessions: [
                      ...importantToGerman,
                      ...legacyImportantEasyToGerman,
                    ],
                    canStart: importantItems.isNotEmpty,
                    key: const Key('create-important-to-german-session'),
                    onAdd: () => _createExtraSession(
                      DailySessionKind.importantVocabularyToGerman,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _marathonCategory(
                  kind: DailySessionKind.marathonToGerman,
                  icon: Icons.flag_outlined,
                  title: s.marathonToGermanCategory,
                  session: marathonToGerman,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lessonGroup(
              group: _LessonGroup.toRussian,
              icon: Icons.arrow_back,
              title: s.toRussianCategory,
              sessions: [
                ...toRussianSessions,
                ...extraToRussian,
                ...importantToRussian,
                if (marathonToRussian != null) marathonToRussian,
              ],
              children: [
                _sessionCategory(
                  kind: DailySessionKind.vocabularyToRussian,
                  icon: Icons.arrow_back,
                  title: s.standardMode,
                  sessions: [...toRussianSessions, ...extraToRussian],
                  canAdd: toRussianComplete || toRussianSessions.isEmpty,
                  addKey: const Key('create-extra-to-russian-session'),
                  onAdd: () =>
                      _createExtraSession(DailySessionKind.vocabularyToRussian),
                  secondaryAction: _SessionSecondaryAction(
                    sessions: importantToRussian,
                    canStart: importantItems.isNotEmpty,
                    key: const Key('create-important-to-russian-session'),
                    onAdd: () => _createExtraSession(
                      DailySessionKind.importantVocabularyToRussian,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _marathonCategory(
                  kind: DailySessionKind.marathonToRussian,
                  icon: Icons.outlined_flag,
                  title: s.marathonToRussianCategory,
                  session: marathonToRussian,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lessonGroup(
              group: _LessonGroup.grammar,
              icon: Icons.school_outlined,
              title: s.grammarCategory,
              sessions: [
                ...grammarSessions,
                ...extraGrammar,
                ...favoriteGrammar,
              ],
              children: [
                _sessionCategory(
                  kind: DailySessionKind.grammar,
                  icon: Icons.school_outlined,
                  title: s.standardMode,
                  sessions: [...grammarSessions, ...extraGrammar],
                  canAdd: grammarComplete || grammarSessions.isEmpty,
                  canStart: _availableGrammarTopics.isNotEmpty,
                  addKey: const Key('create-extra-grammar-session'),
                  onAdd: () => _createExtraSession(DailySessionKind.grammar),
                ),
                const SizedBox(height: 12),
                _featuredBlock(
                  key: const Key('favorite-grammar-lessons-block'),
                  title: s.favoriteGrammarCategory,
                  icon: Icons.auto_awesome,
                  children: [
                    if (_favoriteGrammarTopics.isEmpty &&
                        favoriteGrammar.every((session) => session.isComplete))
                      _featuredHint(
                          Icons.star_outline, s.noFavoriteGrammarHint),
                    _sessionCategory(
                      kind: DailySessionKind.favoriteGrammar,
                      icon: Icons.school_outlined,
                      title: s.favoriteGrammarLesson,
                      sessions: favoriteGrammar,
                      canAdd: true,
                      canStart: _favoriteGrammarTopics.isNotEmpty,
                      addKey: const Key('create-favorite-grammar-session'),
                      onAdd: () =>
                          _createExtraSession(DailySessionKind.favoriteGrammar),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _lessonGroup(
              group: _LessonGroup.other,
              icon: Icons.grid_view_outlined,
              title: s.otherCategory,
              sessions: [
                ...numberSessions,
                ...extraNumbers,
                ...irregularVerbSessions,
                ...matchingSessions,
                ...importantMatchingSessions,
                ...multipleChoiceSessions,
              ],
              children: [
                _sessionCategory(
                  kind: DailySessionKind.grammar,
                  icon: Icons.schema_outlined,
                  title: s.irregularVerbFormsLesson,
                  sessions: irregularVerbSessions,
                  canAdd: true,
                  canStart:
                      _availableGrammarTopics.contains(_irregularVerbTopicId) &&
                          _irregularVerbExercises.length == 27,
                  addKey: const Key('create-irregular-verbs-session'),
                  categoryKeyOverride: 'irregular-verb-forms',
                  onAdd: _createIrregularVerbSession,
                ),
                if (_irregularVerbExercises.length != 27) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.irregularVerbFormsNeedsWords(
                      _irregularVerbExercises.length,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                _sessionCategory(
                  kind: DailySessionKind.numbers,
                  icon: Icons.pin_outlined,
                  title: s.numbersCategory,
                  sessions: [...numberSessions, ...extraNumbers],
                  canAdd: numbersComplete || numberSessions.isEmpty,
                  addKey: const Key('create-extra-number-session-expanded'),
                  onAdd: () => _createExtraSession(DailySessionKind.numbers),
                ),
                const SizedBox(height: 12),
                _sessionCategory(
                  kind: DailySessionKind.matching,
                  icon: Icons.compare_arrows,
                  title: s.matchingCategory,
                  sessions: matchingSessions,
                  canAdd: true,
                  canStart: _matchingCandidates().length >= 2,
                  addKey: const Key('create-matching-session'),
                  onAdd: () => _createExtraSession(DailySessionKind.matching),
                  secondaryAction: _SessionSecondaryAction(
                    sessions: importantMatchingSessions,
                    canStart:
                        _matchingCandidates(importantOnly: true).length >= 2,
                    key: const Key('create-important-matching-session'),
                    onAdd: () =>
                        _createExtraSession(DailySessionKind.importantMatching),
                  ),
                ),
                if (_matchingCandidates().length < 2) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.matchingNeedsWords,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 12),
                _sessionCategory(
                  kind: DailySessionKind.multipleChoice,
                  icon: Icons.checklist_outlined,
                  title: s.multipleChoiceCategory,
                  sessions: multipleChoiceSessions,
                  canAdd: true,
                  canStart: _matchingCandidates().length >= 4,
                  addKey: const Key('create-multiple-choice-session'),
                  onAdd: () =>
                      _createExtraSession(DailySessionKind.multipleChoice),
                ),
                if (_matchingCandidates().length < 4) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.multipleChoiceNeedsWords,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _lessonGroup({
    required _LessonGroup group,
    required IconData icon,
    required String title,
    required List<DailySession> sessions,
    required List<Widget> children,
  }) {
    final expanded = _expandedLessonGroups.contains(group);
    final groupKey =
        group.name.replaceAll(RegExp(r'(?=[A-Z])'), '-').toLowerCase();

    return Container(
      key: Key('lesson-group-$groupKey'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('toggle-lesson-group-$groupKey'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => setState(() {
                if (expanded) {
                  _expandedLessonGroups.remove(group);
                } else {
                  _expandedLessonGroups.add(group);
                }
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Icon(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              key: Key('lesson-group-content-$groupKey'),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _marathonCategory({
    required DailySessionKind kind,
    required IconData icon,
    required String title,
    required DailySession? session,
  }) {
    final inProgress = session?.status == DailySessionStatus.inProgress;
    final completed = session?.isComplete ?? false;
    final categoryKey = kind.wireName.replaceAll('_', '-');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (session != null)
                      Text(
                        widget.strings.sessionAnswers(
                          session.answeredCount,
                          session.targetAnswers,
                        ),
                        key: Key('marathon-progress-$categoryKey'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final reset = OutlinedButton.icon(
                key: Key('reset-marathon-$categoryKey'),
                onPressed:
                    session == null ? null : () => _confirmResetMarathon(kind),
                icon: const Icon(Icons.restart_alt),
                label: Text(widget.strings.resetMarathon),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
              );
              final open = FilledButton.tonalIcon(
                key: Key('open-marathon-$categoryKey'),
                onPressed: _activeItems.isEmpty
                    ? null
                    : () {
                        if (inProgress) {
                          _openSession(session!.id);
                        } else {
                          _confirmResetMarathon(kind, confirm: completed);
                        }
                      },
                icon: Icon(
                  inProgress ? Icons.play_arrow : Icons.flag_outlined,
                ),
                label: Text(
                  inProgress
                      ? widget.strings.continueLesson
                      : completed
                          ? widget.strings.restartMarathon
                          : widget.strings.start,
                ),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
              );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    open,
                    if (session != null) ...[
                      const SizedBox(height: 8),
                      reset,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  if (session != null) Expanded(child: reset),
                  if (session != null) const SizedBox(width: 8),
                  Expanded(child: open),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _confirmResetMarathon(
    DailySessionKind kind, {
    bool confirm = true,
  }) async {
    if (confirm) {
      final accepted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(widget.strings.resetMarathonTitle),
              content: Text(widget.strings.resetMarathonMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(widget.strings.cancel),
                ),
                FilledButton(
                  key: const Key('confirm-reset-marathon'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(widget.strings.resetMarathon),
                ),
              ],
            ),
          ) ??
          false;
      if (!accepted || !mounted) return;
    }
    final items = [..._activeItems]..shuffle(_random);
    final session = await widget.sessions.resetPersistent(
      kind: kind,
      queueItemIds: items.map((item) => item.id).toList(growable: false),
      now: DateTime.now().toUtc(),
    );
    await _openSession(session.id);
  }

  Widget _featuredBlock({
    required Key key,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.55),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.onTertiaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colors.onTertiaryContainer,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _featuredHint(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text)),
          ],
        ),
      );

  Widget _sessionCategory({
    required DailySessionKind kind,
    required IconData icon,
    required String title,
    required List<DailySession> sessions,
    required bool canAdd,
    bool canStart = true,
    required Key addKey,
    required VoidCallback onAdd,
    _SessionSecondaryAction? secondaryAction,
    String? categoryKeyOverride,
  }) {
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
    final categoryKey =
        categoryKeyOverride ?? kind.wireName.replaceAll('_', '-');
    final secondaryInProgress = secondaryAction?.sessions
        .where((session) => session.status == DailySessionStatus.inProgress)
        .firstOrNull;
    final secondaryNext = secondaryAction?.sessions
        .where((session) => session.status == DailySessionStatus.planned)
        .firstOrNull;
    final secondaryEnabled = secondaryAction != null &&
        (secondaryInProgress != null
            ? _canOpenSession(secondaryInProgress)
            : secondaryAction.canStart);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (inProgress != null)
                      Text(
                        widget.strings.sessionAnswers(
                          inProgress.answeredCount,
                          inProgress.targetAnswers,
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (secondaryInProgress != null)
                      Text(
                        '${widget.strings.importantWordsCategory}: '
                        '${widget.strings.sessionAnswers(secondaryInProgress.answeredCount, secondaryInProgress.targetAnswers)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final primary = FilledButton.tonalIcon(
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
                icon: Icon(actionIcon),
                label: Text(actionLabel),
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                ),
              );
              final secondary = secondaryAction == null
                  ? null
                  : Tooltip(
                      message: secondaryAction.canStart
                          ? widget.strings.importantWordsCategory
                          : widget.strings.noImportantWordsHint,
                      child: OutlinedButton.icon(
                        key: secondaryInProgress == null
                            ? secondaryAction.key
                            : Key(
                                'continue-${secondaryInProgress.kind.wireName}',
                              ),
                        onPressed: secondaryEnabled
                            ? () {
                                if (secondaryInProgress != null) {
                                  _selectSession(secondaryInProgress);
                                } else if (secondaryNext != null) {
                                  _selectSession(secondaryNext);
                                } else {
                                  secondaryAction.onAdd();
                                }
                              }
                            : null,
                        icon: Icon(
                          secondaryInProgress != null
                              ? Icons.play_arrow
                              : Icons.star_outline,
                        ),
                        label: Text(
                          secondaryInProgress != null
                              ? widget.strings.continueImportantWords
                              : widget.strings.importantWordsCategory,
                        ),
                        style: const ButtonStyle(
                          minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                        ),
                      ),
                    );
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    primary,
                    if (secondary != null) ...[
                      const SizedBox(height: 8),
                      secondary,
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  if (secondary != null) Expanded(child: secondary),
                  if (secondary != null) const SizedBox(width: 8),
                  Expanded(child: primary),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _canOpenSession(DailySession session) => switch (session.kind) {
        DailySessionKind.grammar =>
          _availableGrammarTopics.isNotEmpty || session.queueItemIds.isNotEmpty,
        DailySessionKind.favoriteGrammar =>
          _favoriteGrammarTopics.isNotEmpty || session.queueItemIds.isNotEmpty,
        DailySessionKind.numbers => true,
        DailySessionKind.importantMatching => session.queueItemIds.isNotEmpty ||
            _matchingCandidates(importantOnly: true).length >= 2,
        DailySessionKind.importantVocabularyToGerman ||
        DailySessionKind.importantEasyVocabularyToGerman ||
        DailySessionKind.importantVocabularyToRussian =>
          session.queueItemIds.isNotEmpty ||
              _activeItems.any((item) => item.isImportant),
        _ => _activeItems.isNotEmpty,
      };

  Widget _withMultipleChoiceShortcuts(Widget child) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _answerMultipleChoice(null),
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _selectChoiceByIndex(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _selectChoiceByIndex(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _selectChoiceByIndex(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _selectChoiceByIndex(3),
        const SingleActivator(LogicalKeyboardKey.enter): _nextMultipleChoice,
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  Widget _multipleChoicePractice() {
    final s = widget.strings;
    final item = _current;
    if (item == null) {
      return _CenteredPanel(
        icon: Icons.checklist_outlined,
        title: s.multipleChoiceCategory,
        message: s.reviewEmpty,
      );
    }
    final prompt = _choiceToRussian
        ? learningItemGermanWithPlural(item)
        : _primaryTranslation(item);
    return Center(
      child: SingleChildScrollView(
        padding: AppLayout.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: _practiceCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('back-to-plan'),
                      onPressed: _savingVocabularyAnswer ? null : _load,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(s.dailyPlan),
                    ),
                  ),
                  Text(
                    _progressLabel(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(s.multipleChoiceHint),
                  const SizedBox(height: 20),
                  Text(
                    prompt,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  for (var index = 0;
                      index < _choiceOptions.length;
                      index++) ...[
                    _multipleChoiceButton(
                      item: _choiceOptions[index],
                      index: index,
                      correctItemId: item.id,
                    ),
                    if (index != _choiceOptions.length - 1)
                      const SizedBox(height: 10),
                  ],
                  if (_answered) ...[
                    const SizedBox(height: 20),
                    Text(
                      _lastCorrect ? s.correct : s.incorrect,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const Key('multiple-choice-next'),
                      onPressed: _nextMultipleChoice,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        _repeatIncorrectImmediately && !_lastCorrect
                            ? s.tryAgain
                            : s.next,
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

  Widget _multipleChoiceButton({
    required LearningItem item,
    required int index,
    required String correctItemId,
  }) {
    final colors = Theme.of(context).colorScheme;
    final isCorrect = item.id == correctItemId;
    final selected = item.id == _selectedChoiceItemId;
    final revealCorrect = _answered && isCorrect;
    final revealWrong = _answered && selected && !isCorrect;
    final label = _choiceToRussian
        ? _primaryTranslation(item)
        : learningItemGermanWithPlural(item);
    return OutlinedButton(
      key: Key('multiple-choice-option-${index + 1}'),
      onPressed: _answered || _savingVocabularyAnswer
          ? null
          : () => _answerMultipleChoice(item),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        foregroundColor: revealCorrect
            ? colors.onPrimaryContainer
            : revealWrong
                ? colors.onErrorContainer
                : null,
        backgroundColor: revealCorrect
            ? colors.primaryContainer
            : revealWrong
                ? colors.errorContainer
                : null,
      ),
      child: Text('${index + 1}. $label', textAlign: TextAlign.center),
    );
  }

  void _selectChoiceByIndex(int index) {
    if (_answered ||
        _savingVocabularyAnswer ||
        index >= _choiceOptions.length) {
      return;
    }
    _answerMultipleChoice(_choiceOptions[index]);
  }

  Future<void> _answerMultipleChoice(LearningItem? selected) async {
    final item = _current;
    if (item == null || _answered || _savingVocabularyAnswer) return;
    final correct = selected?.id == item.id;
    final answer = selected == null
        ? ''
        : _choiceToRussian
            ? _primaryTranslation(selected)
            : learningItemGermanWithPlural(selected);
    if (_isCorrection) {
      setState(() {
        _selectedChoiceItemId = selected?.id;
        _lastCorrect = correct;
        _answered = true;
      });
      return;
    }
    setState(() => _savingVocabularyAnswer = true);
    try {
      var remaining = _queue.skip(1).toList(growable: false);
      if (!correct) remaining = _withDelayedControl(remaining, item);
      final updated = await widget.sessions.recordAnswer(
        attempt: PracticeAttempt(
          id: newUuidV4(),
          itemId: item.id,
          sessionId: _session!.id,
          answerText: answer,
          correct: correct,
          attemptedAt: DateTime.now().toUtc(),
        ),
        remainingQueueItemIds:
            remaining.map((entry) => entry.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
      widget.onAttemptSaved();
      if (!mounted) return;
      setState(() {
        _session = updated;
        _nextQueue = remaining;
        _selectedChoiceItemId = selected?.id;
        _lastCorrect = correct;
        _answered = true;
        _savingVocabularyAnswer = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingVocabularyAnswer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.answerSaveFailed)),
      );
    }
  }

  void _nextMultipleChoice() {
    if (!_answered) return;
    if (_repeatIncorrectImmediately && !_lastCorrect) {
      setState(() {
        _selectedChoiceItemId = null;
        _answered = false;
        _isCorrection = true;
      });
      return;
    }
    setState(() {
      _queue = _nextQueue;
      _nextQueue = const [];
      _selectedChoiceItemId = null;
      _answered = false;
      _isCorrection = false;
      _complete = _session!.isComplete;
    });
    if (!_complete) _prepareMultipleChoiceOptions();
  }

  void _prepareMultipleChoiceOptions() {
    final item = _current;
    if (item == null || _session == null) return;
    final toRussian = _session!.answeredCount.isEven;
    final candidates = _matchingCandidates()
        .where((candidate) => candidate.id != item.id)
        .toList()
      ..shuffle(_random);
    final options = <LearningItem>[item];
    final labels = <String>{
      _multipleChoiceLabelKey(item, toRussian: toRussian),
    };
    for (final candidate in candidates) {
      if (labels.add(
        _multipleChoiceLabelKey(candidate, toRussian: toRussian),
      )) {
        options.add(candidate);
      }
      if (options.length == 4) break;
    }
    options.shuffle(_random);
    setState(() {
      _choiceToRussian = toRussian;
      _choiceOptions = options;
    });
  }

  String _multipleChoiceLabelKey(
    LearningItem item, {
    required bool toRussian,
  }) =>
      toRussian
          ? normalizeRussianPracticeAnswer(_primaryTranslation(item))
          : normalizePracticeAnswer(
              learningItemGermanWithPlural(item),
            ).toLowerCase();

  Widget _matchingPractice() {
    final s = widget.strings;
    final byId = {for (final item in _matchingBoard) item.id: item};
    final russianItems = _matchingRussianOrder
        .map((id) => byId[id])
        .whereType<LearningItem>()
        .toList(growable: false);
    return Center(
      child: SingleChildScrollView(
        padding: AppLayout.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Card(
            child: Padding(
              padding: _practiceCardPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('back-to-plan'),
                      onPressed: _savingVocabularyAnswer ? null : _load,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(s.dailyPlan),
                    ),
                  ),
                  Text(
                    _progressLabel(),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(s.matchingHint),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in _matchingBoard)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _matchingCard(
                                  key: Key('matching-german-${item.id}'),
                                  label: learningItemGermanWithPlural(item),
                                  selected: _selectedMatchingItemId == item.id,
                                  matched: _matchedItemIds.contains(item.id),
                                  wrong: _wrongMatchingPair?.$1 == item.id,
                                  onPressed:
                                      _matchedItemIds.contains(item.id) ||
                                              _savingVocabularyAnswer
                                          ? null
                                          : () => setState(
                                                () => _selectedMatchingItemId =
                                                    item.id,
                                              ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in russianItems)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _matchingCard(
                                  key: Key('matching-russian-${item.id}'),
                                  label: _primaryTranslation(item),
                                  selected: false,
                                  matched: _matchedItemIds.contains(item.id),
                                  wrong: _wrongMatchingPair?.$2 == item.id,
                                  onPressed: _matchedItemIds
                                              .contains(item.id) ||
                                          _selectedMatchingItemId == null ||
                                          _savingVocabularyAnswer
                                      ? null
                                      : () => _selectMatchingTranslation(item),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _matchingCard({
    required Key key,
    required String label,
    required bool selected,
    required bool matched,
    required bool wrong,
    required VoidCallback? onPressed,
  }) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: matched
            ? colors.onPrimaryContainer
            : wrong
                ? colors.onErrorContainer
                : null,
        backgroundColor: matched
            ? colors.primaryContainer
            : wrong
                ? colors.errorContainer
                : selected
                    ? colors.secondaryContainer
                    : null,
        side: selected ? BorderSide(color: colors.secondary, width: 2) : null,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  String _primaryTranslation(LearningItem item) => learningItemMeaning(item)
      .split(';')
      .map((value) => value.trim())
      .firstWhere((value) => value.isNotEmpty, orElse: () => '—');

  List<LearningItem> _matchingCandidates({bool importantOnly = false}) {
    final german = <String>{};
    final russian = <String>{};
    final result = <LearningItem>[];
    for (final item in _activeItems) {
      if (importantOnly && !item.isImportant) continue;
      final germanKey = normalizePracticeAnswer(
        learningItemGermanWithPlural(item),
      ).toLowerCase();
      final russianKey = normalizeRussianPracticeAnswer(
        _primaryTranslation(item),
      );
      if (germanKey.isEmpty || russianKey.isEmpty || russianKey == '—') {
        continue;
      }
      if (german.add(germanKey) && russian.add(russianKey)) result.add(item);
    }
    return result;
  }

  Future<void> _selectMatchingTranslation(LearningItem russianItem) async {
    final germanItemId = _selectedMatchingItemId;
    if (germanItemId == null || _savingVocabularyAnswer) return;
    final germanItem =
        _matchingBoard.where((item) => item.id == germanItemId).firstOrNull;
    if (germanItem == null) return;
    if (germanItem.id != russianItem.id) {
      if (!_matchingFailedItemIds.contains(germanItem.id)) {
        await widget.practice.saveAttempt(
          PracticeAttempt(
            id: newUuidV4(),
            itemId: germanItem.id,
            sessionId: _session!.id,
            answerText: _primaryTranslation(russianItem),
            correct: false,
            attemptedAt: DateTime.now().toUtc(),
          ),
        );
        widget.onAttemptSaved();
      }
      if (!mounted) return;
      setState(() {
        _matchingFailedItemIds = {
          ..._matchingFailedItemIds,
          germanItem.id,
        };
        _wrongMatchingPair = (germanItem.id, russianItem.id);
        _selectedMatchingItemId = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (mounted && _wrongMatchingPair == (germanItem.id, russianItem.id)) {
        setState(() => _wrongMatchingPair = null);
      }
      return;
    }

    setState(() => _savingVocabularyAnswer = true);
    try {
      var remaining = _queue
          .where((item) => item.id != germanItem.id)
          .toList(growable: false);
      if (_matchingFailedItemIds.contains(germanItem.id)) {
        remaining = _withDelayedControl(remaining, germanItem);
      }
      final updated = await widget.sessions.recordAnswer(
        attempt: PracticeAttempt(
          id: newUuidV4(),
          itemId: germanItem.id,
          sessionId: _session!.id,
          answerText: _primaryTranslation(russianItem),
          correct: true,
          attemptedAt: DateTime.now().toUtc(),
        ),
        remainingQueueItemIds:
            remaining.map((item) => item.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
      widget.onAttemptSaved();
      if (!mounted) return;
      final matched = {..._matchedItemIds, germanItem.id};
      final boardComplete =
          _matchingBoard.every((item) => matched.contains(item.id));
      setState(() {
        _session = updated;
        _queue = remaining;
        _matchedItemIds = matched;
        _selectedMatchingItemId = null;
        _savingVocabularyAnswer = false;
        _complete = updated.isComplete;
        if (boardComplete && !updated.isComplete) {
          _prepareMatchingBoard(remaining);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingVocabularyAnswer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.answerSaveFailed)),
      );
    }
  }

  void _prepareMatchingBoard(List<LearningItem> remaining) {
    _matchingBoard = remaining
        .take(widget.appSettings.matchingPairsPerBoard)
        .toList(growable: false);
    _matchingRussianOrder = _matchingBoard.map((item) => item.id).toList()
      ..shuffle(_random);
    _matchedItemIds = <String>{};
    _matchingFailedItemIds = <String>{};
    _selectedMatchingItemId = null;
    _wrongMatchingPair = null;
  }

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
        padding: AppLayout.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Card(
            child: Padding(
              padding: _practiceCardPadding(context),
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
                    _progressLabel(),
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
                      child: Text(
                        _repeatIncorrectImmediately && !_lastCorrect
                            ? s.tryAgain
                            : s.next,
                      ),
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
        padding: AppLayout.pagePadding(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Card(
            child: Padding(
              padding: _practiceCardPadding(context),
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
                    _progressLabel(),
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
                          if (!_lastCorrect &&
                              exercise != null &&
                              exercise.type != GrammarExerciseType.forms)
                            Text(s.correctAnswer(exercise.answer)),
                          if (!_lastCorrect &&
                              exercise?.type == GrammarExerciseType.forms)
                            ...exercise!.formAnswers.entries.map(
                              (entry) => Text(
                                '${s.grammarFormLabel(entry.key)}: '
                                '${entry.value.first}',
                              ),
                            ),
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
                      child: Text(
                        _repeatIncorrectImmediately && !_lastCorrect
                            ? s.tryAgain
                            : s.next,
                      ),
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
      case GrammarExerciseType.forms:
        return _grammarFormFields(exercise);
    }
  }

  Widget _grammarFormFields(GrammarExercise exercise) {
    final entries = exercise.formAnswers.entries.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final indexedEntry in entries.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final index = indexedEntry.$1;
                final entry = indexedEntry.$2;
                final controller = _grammarControllers.putIfAbsent(
                  entry.key,
                  TextEditingController.new,
                );
                final correct = _grammarResults[entry.key];
                final editable = !_isCorrection ||
                    _grammarCorrectionKeys.contains(entry.key);
                final field = TextField(
                  key: Key('grammar-form-${entry.key}'),
                  controller: controller,
                  focusNode: index == 0 ? _answerFocus : null,
                  enabled: !_answered && editable,
                  decoration: InputDecoration(
                    isDense: true,
                    errorText: _answered && correct == false
                        ? entry.value.first
                        : null,
                  ),
                );
                final label = Text(
                  widget.strings.grammarFormLabel(entry.key),
                  style: Theme.of(context).textTheme.labelLarge,
                );
                if (constraints.maxWidth < 520) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      label,
                      const SizedBox(height: 6),
                      field,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 180, child: label),
                    const SizedBox(width: 12),
                    Expanded(child: field),
                  ],
                );
              },
            ),
          ),
      ],
    );
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
          final editable =
              !_isCorrection || _grammarCorrectionKeys.contains(entry.key);
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
                    enabled: !_answered && editable,
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
    final standardTopics = availableTopics.where(
      (id) =>
          _catalog.topics
              .where((topic) => topic.id == id)
              .firstOrNull
              ?.practiceSection ==
          'grammar',
    );
    final sessions = await widget.sessions.ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
      includeGrammar: standardTopics.isNotEmpty,
    );
    final persistentSessions = <DailySession>[
      if (await widget.sessions.findPersistent(
        DailySessionKind.marathonToGerman,
      )
          case final session?)
        session,
      if (await widget.sessions.findPersistent(
        DailySessionKind.marathonToRussian,
      )
          case final session?)
        session,
    ];
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
      _favoriteGrammarTopics = grammarProgress.values
          .where((entry) => entry.favorite)
          .map((entry) => entry.topicId)
          .where(availableTopics.contains)
          .where(
            (id) =>
                _catalog.topics
                    .where((topic) => topic.id == id)
                    .firstOrNull
                    ?.practiceSection ==
                'grammar',
          )
          .toSet();
      _daySessions = sessions;
      _persistentSessions = persistentSessions;
      _session = null;
      _queue = const [];
      _grammarQueue = const [];
      _numberQueue = const [];
      _choiceOptions = const [];
      _selectedChoiceItemId = null;
      _focusedGrammarTopicId = null;
      _answered = false;
      _isCorrection = false;
      _grammarCorrectionKeys = const {};
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

  bool _isTopicSession(
    DailySession session,
    String topicId, {
    GrammarCatalog? catalog,
  }) {
    if (!session.kind.isGrammar) return false;
    final resolvedCatalog = catalog ?? _catalog;
    if (session.queueItemIds.isNotEmpty) {
      return session.queueItemIds.every(
        (id) => resolvedCatalog.exercise(id)?.topicId == topicId,
      );
    }
    return resolvedCatalog.exercise(session.lastItemId ?? '')?.topicId ==
        topicId;
  }

  Future<void> _createExtraSession(DailySessionKind kind) async {
    final extra = await widget.sessions.createExtra(
      localDate: localDayKey(DateTime.now()),
      now: DateTime.now().toUtc(),
      kind: kind,
    );
    await _openSession(extra.id);
  }

  Future<void> _createIrregularVerbSession() async {
    final exercises = [..._irregularVerbExercises]..shuffle(_random);
    if (exercises.length != 27) return;
    setState(() => _loading = true);
    var session = await widget.sessions.createExtra(
      localDate: localDayKey(DateTime.now()),
      now: DateTime.now().toUtc(),
      kind: DailySessionKind.grammar,
    );
    session = await widget.sessions.start(
      id: session.id,
      queueItemIds: exercises.map((exercise) => exercise.id).toList(),
      now: DateTime.now().toUtc(),
    );
    await _openSession(session.id);
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
    if (topicId == _irregularVerbTopicId) {
      await _createIrregularVerbSession();
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
    if (session.status == DailySessionStatus.inProgress &&
        session.contentVersion != widget.grammarCatalog.contentVersion &&
        _isTopicSession(
          session,
          _irregularVerbTopicId,
          catalog: widget.grammarCatalog,
        )) {
      final exercises = [
        ...widget.grammarCatalog.exercisesFor(
          topicId: _irregularVerbTopicId,
          activeItemKeys: _activeItemKeys(_activeItems),
        ),
      ]..shuffle(_random);
      if (exercises.length == 27) {
        session = await widget.sessions.restart(
          id: session.id,
          queueItemIds:
              exercises.map((exercise) => exercise.id).toList(growable: false),
          now: DateTime.now().toUtc(),
        );
      }
    }
    if (session.kind.isGrammar) {
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
    if (session.kind == DailySessionKind.matching ||
        session.kind == DailySessionKind.importantMatching) {
      await _openMatchingSession(session);
      return;
    }
    if (session.kind == DailySessionKind.multipleChoice) {
      await _openMultipleChoiceSession(session);
      return;
    }
    var queue = _itemsForIds(session.queueItemIds);
    if (session.status == DailySessionStatus.planned) {
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
    } else if (queue.isNotEmpty && queue.length != session.remaining) {
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
      _isCorrection = false;
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

  Future<void> _openMatchingSession(DailySession session) async {
    var queue = _itemsForIds(session.queueItemIds);
    if (session.status == DailySessionStatus.planned) {
      final candidates = _matchingCandidates(
        importantOnly: session.kind == DailySessionKind.importantMatching,
      )..shuffle(_random);
      queue = candidates.take(24).toList(growable: false);
      if (queue.length < 2) {
        await _load();
        return;
      }
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue.map((item) => item.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
    } else if (queue.isNotEmpty && queue.length != session.remaining) {
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue.map((item) => item.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _queue = queue;
      _prepareMatchingBoard(queue);
      _isCorrection = false;
      _savingVocabularyAnswer = false;
      _complete = session.isComplete;
      _loading = false;
    });
  }

  Future<void> _openMultipleChoiceSession(DailySession session) async {
    var queue = _itemsForIds(session.queueItemIds);
    if (session.status == DailySessionStatus.planned) {
      final candidates = _matchingCandidates()..shuffle(_random);
      queue = candidates.take(20).toList(growable: false);
      if (queue.length < 4) {
        await _load();
        return;
      }
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue.map((item) => item.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
    } else if (queue.isNotEmpty && queue.length != session.remaining) {
      session = await widget.sessions.start(
        id: session.id,
        queueItemIds: queue.map((item) => item.id).toList(growable: false),
        now: DateTime.now().toUtc(),
      );
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _queue = queue;
      _nextQueue = const [];
      _choiceOptions = const [];
      _selectedChoiceItemId = null;
      _answered = false;
      _isCorrection = false;
      _savingVocabularyAnswer = false;
      _complete = session.isComplete;
      _loading = false;
    });
    if (!session.isComplete) _prepareMultipleChoiceOptions();
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
      _isCorrection = false;
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
        topicIds: session.kind == DailySessionKind.favoriteGrammar
            ? _favoriteGrammarTopics
            : null,
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
      _grammarCorrectionKeys = const {};
      _answered = false;
      _isCorrection = false;
      _complete = session.isComplete;
      _loading = false;
    });
    if (queue.isNotEmpty) _focusAnswerField();
  }

  Future<List<String>> _buildGrammarQueue({
    required int length,
    required bool includeParadigm,
    String? topicId,
    Set<String>? topicIds,
  }) async {
    if (length <= 0 || _availableGrammarTopics.isEmpty) return const [];
    final selectedTopicIds = topicIds ??
        (topicId == null
            ? _standardGrammarTopicIds
            : _availableGrammarTopics.where((id) => id == topicId).toSet());
    if (selectedTopicIds.isEmpty) return const [];
    final outcomes = await widget.grammar.recentOutcomes();
    final itemKeys = _activeItemKeys(_activeItems);
    final verbLemmas = _verbLemmas(_activeItems);
    final used = _daySessions.expand((session) => session.queueItemIds).toSet();
    final queue = <String>[];
    if (includeParadigm) {
      final conjugationTopics = selectedTopicIds
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
      itemIds: selectedTopicIds.toList(growable: false),
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

    final allEligible = selectedTopicIds
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
    final seen = <String>{};
    return ids
        .where(seen.add)
        .map((id) => byId[id])
        .whereType<LearningItem>()
        .toList();
  }

  Future<List<LearningItem>> _buildQueue({
    required int length,
    String? previousItemId,
    List<LearningItem>? items,
  }) async {
    final outcomes = await widget.practice.recentOutcomes();
    final candidates = items ?? _activeItems;
    final ids = buildWeightedUniqueQueue(
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

    if (_isCorrection) {
      setState(() {
        _answered = true;
        _lastCorrect = correct;
        _pendingVocabularyAnswer = null;
      });
      _focusNextButton();
      return;
    }

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
    final nextQueue = _queue.skip(1).toList(growable: true);
    if (!correct) {
      final delayed = _withDelayedControl(nextQueue, item);
      nextQueue
        ..clear()
        ..addAll(delayed);
    }
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
    return (updatedSession, nextQueue.toList(growable: false));
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
    if (_isCorrection) {
      setState(() {
        _lastCorrect = correct;
        _answered = true;
      });
      _focusNextButton();
      return;
    }
    var remaining = _numberQueue.skip(1).toList(growable: false);
    if (!correct) remaining = _withDelayedControl(remaining, taskId);
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
        if (_isCorrection && !_grammarCorrectionKeys.contains(entry.key)) {
          results[entry.key] = true;
          continue;
        }
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
      if (exercise.type == GrammarExerciseType.forms) {
        for (final entry in exercise.formAnswers.entries) {
          if (_isCorrection && !_grammarCorrectionKeys.contains(entry.key)) {
            results[entry.key] = true;
            continue;
          }
          final answer = _grammarControllers[entry.key]?.text.trim() ?? '';
          if (answer.isEmpty && !allowEmpty) return;
          final correct = isAnyPracticeAnswerCorrect(
            answer: answer,
            expectedAlternatives: entry.value.join(';'),
          );
          results[entry.key] = correct;
          attempts.add(
            GrammarAttempt(
              id: newUuidV4(),
              topicId: exercise.topicId,
              exerciseId: '${exercise.id}:${entry.key}',
              sessionId: _session!.id,
              answerText: answer,
              correct: correct,
              attemptedAt: now,
            ),
          );
        }
      } else {
        final answer = switch (exercise.type) {
          GrammarExerciseType.text => _answerController.text.trim(),
          GrammarExerciseType.choice ||
          GrammarExerciseType.yesNo =>
            _selectedGrammarOption ?? '',
          GrammarExerciseType.wordOrder => _wordOrderAnswer(exercise),
          GrammarExerciseType.forms => throw StateError(
              'Form exercises are handled separately.',
            ),
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
    }

    final allCorrect = results.values.every((value) => value);
    if (_isCorrection) {
      if (!mounted) return;
      setState(() {
        _grammarResults = results;
        _grammarCorrectionKeys = results.entries
            .where((entry) => !entry.value)
            .map((entry) => entry.key)
            .toSet();
        _lastCorrect = allCorrect;
        _answered = true;
      });
      _focusNextButton();
      return;
    }

    var remaining = _grammarQueue.skip(1).toList(growable: false);
    if (!allCorrect) remaining = _withDelayedControl(remaining, taskId);
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
      _grammarCorrectionKeys = results.entries
          .where((entry) => !entry.value)
          .map((entry) => entry.key)
          .toSet();
      _lastCorrect = allCorrect;
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
    if (_repeatIncorrectImmediately && !_lastCorrect) {
      final paradigm = _paradigm(_currentGrammar!);
      final exercise = _catalog.exercise(_currentGrammar!);
      if (paradigm == null && exercise?.type != GrammarExerciseType.forms) {
        _clearGrammarInput();
      } else {
        for (final key in _grammarCorrectionKeys) {
          _grammarControllers[key]?.clear();
        }
      }
      setState(() {
        _grammarResults = const {};
        _answered = false;
        _isCorrection = true;
      });
      _focusAnswerField();
      return;
    }
    _clearGrammarInput();
    setState(() {
      _grammarQueue = _nextGrammarQueue;
      _nextGrammarQueue = const [];
      _grammarResults = const {};
      _grammarCorrectionKeys = const {};
      _answered = false;
      _isCorrection = false;
      _complete = _session!.isComplete;
    });
    if (!_complete && _grammarQueue.isNotEmpty) _focusAnswerField();
  }

  void _nextNumber() {
    if (_repeatIncorrectImmediately && !_lastCorrect) {
      setState(() {
        _answerController.clear();
        _answered = false;
        _isCorrection = true;
      });
      _focusAnswerField();
      return;
    }
    setState(() {
      _answerController.clear();
      _numberQueue = _nextNumberQueue;
      _nextNumberQueue = const [];
      _answered = false;
      _isCorrection = false;
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
    if (_repeatIncorrectImmediately && !_lastCorrect) {
      setState(() {
        _answerController.clear();
        _answered = false;
        _isCorrection = true;
        _showVocabularyHelp = false;
      });
      _focusAnswerField();
      return;
    }
    setState(() {
      _answerController.clear();
      _queue = _nextQueue;
      _nextQueue = const [];
      _answered = false;
      _isCorrection = false;
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

final class _SessionSecondaryAction {
  const _SessionSecondaryAction({
    required this.sessions,
    required this.canStart,
    required this.key,
    required this.onAdd,
  });

  final List<DailySession> sessions;
  final bool canStart;
  final Key key;
  final VoidCallback onAdd;
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
        padding: AppLayout.pagePadding(context),
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
