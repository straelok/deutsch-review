import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/answer_checker.dart';
import '../../domain/daily_session.dart';
import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/daily_session_repository.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../domain/word_priority.dart';
import '../../l10n/ui_strings.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({
    required this.learningItems,
    required this.practice,
    required this.sessions,
    required this.strings,
    required this.requestedSessionId,
    required this.requestRevision,
    required this.refreshToken,
    required this.onAttemptSaved,
    super.key,
  });

  final LearningItemRepository learningItems;
  final PracticeRepository practice;
  final DailySessionRepository sessions;
  final UiStrings strings;
  final String? requestedSessionId;
  final int requestRevision;
  final int refreshToken;
  final VoidCallback onAttemptSaved;

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
  DailySession? _session;
  List<LearningItem> _nextQueue = const [];
  bool _loading = true;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _complete = false;

  LearningItem? get _current => _queue.isEmpty ? null : _queue.first;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestRevision != oldWidget.requestRevision &&
        widget.requestedSessionId != null) {
      _openSession(widget.requestedSessionId!);
    } else if (widget.refreshToken != oldWidget.refreshToken &&
        _session == null) {
      _load();
    }
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocus.dispose();
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
    if (_activeItems.isEmpty) {
      return _CenteredPanel(
        icon: Icons.school_outlined,
        title: s.learn,
        message: s.reviewEmpty,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(s.learn, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(s.chooseSession),
        const SizedBox(height: 16),
        ..._daySessions.where((session) => session.isRequired).map(
              (session) => Card(
                child: ListTile(
                  title: Text(s.sessionNumber(session.slot!)),
                  subtitle: Text(
                    s.sessionAnswers(
                      session.answeredCount,
                      session.targetAnswers,
                    ),
                  ),
                  trailing: FilledButton(
                    key: session.slot == 1
                        ? const Key('start-review')
                        : Key('start-review-${session.slot}'),
                    onPressed: () => _selectSession(session),
                    child: Text(
                      session.isComplete
                          ? s.repeatSession
                          : session.status == DailySessionStatus.inProgress
                              ? s.continueSession
                              : s.start,
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final results = await Future.wait<Object>([
      widget.learningItems.findActive(),
      widget.sessions.ensureDay(
        localDate: localDayKey(now),
        now: now.toUtc(),
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _activeItems = (results[0] as List<LearningItem>)
          .where(
            (item) =>
                item.type == LearningItemType.word ||
                item.type == LearningItemType.noun,
          )
          .toList(growable: false);
      _daySessions = results[1] as List<DailySession>;
      _session = null;
      _queue = const [];
      _answered = false;
      _complete = false;
      _loading = false;
    });
  }

  Future<void> _selectSession(DailySession session) async {
    if (session.isComplete) {
      final extra = await widget.sessions.createExtra(
        localDate: localDayKey(DateTime.now()),
        now: DateTime.now().toUtc(),
      );
      await _openSession(extra.id);
    } else {
      await _openSession(session.id);
    }
  }

  Future<void> _openSession(String id) async {
    setState(() => _loading = true);
    final activeItems = await widget.learningItems.findActive();
    _activeItems = activeItems
        .where(
          (item) =>
              item.type == LearningItemType.word ||
              item.type == LearningItemType.noun,
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
