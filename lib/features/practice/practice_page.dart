import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/answer_checker.dart';
import '../../domain/id_generator.dart';
import '../../domain/learning_item.dart';
import '../../domain/learning_item_display.dart';
import '../../domain/practice.dart';
import '../../domain/repositories/learning_item_repository.dart';
import '../../domain/repositories/practice_repository.dart';
import '../../l10n/ui_strings.dart';

class PracticePage extends StatefulWidget {
  const PracticePage({
    required this.learningItems,
    required this.practice,
    required this.strings,
    required this.onAttemptSaved,
    super.key,
  });

  final LearningItemRepository learningItems;
  final PracticeRepository practice;
  final UiStrings strings;
  final VoidCallback onAttemptSaved;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  final _answerController = TextEditingController();
  final _answerFocus = FocusNode();
  List<LearningItem> _queue = const [];
  String? _sessionId;
  bool _loading = true;
  bool _started = false;
  bool _answered = false;
  bool _lastCorrect = false;
  bool _complete = false;

  LearningItem? get _current => _queue.isEmpty ? null : _queue.first;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_started) {
      return _CenteredPanel(
        icon: Icons.school_outlined,
        title: s.learn,
        message: _queue.isEmpty ? s.reviewEmpty : s.reviewIntro,
        action: _queue.isEmpty
            ? null
            : FilledButton.icon(
                key: const Key('start-review'),
                onPressed: _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(s.startReview),
              ),
      );
    }
    if (_complete) {
      return _CenteredPanel(
        icon: Icons.celebration_outlined,
        title: s.sessionComplete,
        message: s.sessionCompleteHint,
        action: FilledButton.icon(
          onPressed: _loadAvailability,
          icon: const Icon(Icons.replay),
          label: Text(s.again),
        ),
      );
    }

    final item = _current!;
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
                    s.progress(_queue.length),
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

  Future<void> _loadAvailability() async {
    setState(() => _loading = true);
    final items = await widget.learningItems.findActive();
    if (!mounted) return;
    setState(() {
      _queue = items
          .where(
            (item) =>
                item.type == LearningItemType.word ||
                item.type == LearningItemType.noun,
          )
          .toList(growable: true);
      _queue.shuffle(Random());
      _started = false;
      _complete = false;
      _answered = false;
      _loading = false;
    });
  }

  void _start() {
    setState(() {
      _sessionId = newUuidV4();
      _started = true;
    });
    _answerFocus.requestFocus();
  }

  Future<void> _checkAnswer() async {
    if (_answered || _answerController.text.trim().isEmpty) return;
    final item = _current!;
    final correct = isPracticeAnswerCorrect(
      answer: _answerController.text,
      expected: learningItemGerman(item),
    );
    await widget.practice.saveAttempt(
      PracticeAttempt(
        id: newUuidV4(),
        itemId: item.id,
        sessionId: _sessionId!,
        answerText: _answerController.text.trim(),
        correct: correct,
        attemptedAt: DateTime.now().toUtc(),
      ),
    );
    widget.onAttemptSaved();
    if (!mounted) return;
    setState(() {
      _answered = true;
      _lastCorrect = correct;
    });
  }

  void _next() {
    final item = _queue.removeAt(0);
    if (!_lastCorrect) {
      _queue.insert(min(2, _queue.length), item);
    }
    setState(() {
      _answerController.clear();
      _answered = false;
      _complete = _queue.isEmpty;
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
