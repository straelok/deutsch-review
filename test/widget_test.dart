import 'package:deutsch_review/app.dart';
import 'dart:convert';

import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_grammar_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_daily_session_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_practice_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_settings_repository.dart';
import 'package:deutsch_review/domain/app_language.dart';
import 'package:deutsch_review/domain/daily_session.dart';
import 'package:deutsch_review/domain/german_numbers.dart';
import 'package:deutsch_review/domain/grammar.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:deutsch_review/domain/practice.dart';
import 'package:deutsch_review/grammar/grammar_catalog.dart';
import 'package:deutsch_review/sync/sqlite_sync_store.dart';
import 'package:deutsch_review/sync/sync_controller.dart';
import 'package:deutsch_review/sync/sync_gateway.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigiert zum leeren Materialbereich', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(find.text('0 von 8 Sitzungen abgeschlossen'), findsOneWidget);
    expect(find.text('Wörter auf Deutsch · Übung 1'), findsNothing);
    expect(
      find.byKey(
        const Key('session-category-action-vocabulary-to-german'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Wörter'), findsOneWidget);
    expect(find.text('0 Wörter'), findsOneWidget);
    expect(find.byKey(const Key('import-json')), findsOneWidget);
    expect(find.byKey(const Key('export-json')), findsOneWidget);
  });

  testWidgets('fügt ein Wort hinzu und bearbeitet es', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-material')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('german')), 'lernen');
    await tester.enterText(find.byKey(const Key('translation')), 'учить');
    await tester.enterText(
      find.byKey(const Key('usage-example')),
      'Ich lerne Deutsch.',
    );
    await tester.enterText(
        find.byKey(const Key('note')), 'Неправильный глагол');
    expect(find.text('Niveau'), findsNothing);
    expect(find.text('Lektion'), findsNothing);
    expect(find.text('Thema'), findsNothing);
    expect(find.text('Quelle'), findsNothing);
    expect(find.text('Im Kurs gelernt'), findsNothing);
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('lernen'), findsOneWidget);
    expect(find.text('Beispiel: Ich lerne Deutsch.'), findsOneWidget);
    expect(find.text('Notiz: Неправильный глагол'), findsOneWidget);
    expect(find.text('Letzte 10: –'), findsOneWidget);
    expect(find.text('Gesamt: –'), findsOneWidget);
    expect(find.text('1 Wörter'), findsOneWidget);
    expect(find.textContaining('Hinzugefügt:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('german')), 'wiederholen');
    await tester.enterText(find.byKey(const Key('note')), 'Повторять материал');
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('wiederholen'), findsOneWidget);
    expect(find.text('Notiz: Повторять материал'), findsOneWidget);
    expect(find.text('lernen'), findsNothing);
  });

  testWidgets('fügt ein Nomen mit Artikel und Plural hinzu', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-material')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('material-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nomen').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('german')), 'Tisch');
    await tester.enterText(find.byKey(const Key('plural')), 'Tische');
    await tester.enterText(find.byKey(const Key('translation')), 'стол');
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('der Tisch'), findsOneWidget);
    expect(find.textContaining('стол'), findsOneWidget);
  });

  testWidgets('shows recent and all-time statistics in the word list', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final items = SqliteLearningItemRepository(database);
    final practice = SqlitePracticeRepository(database);
    final word = _word();
    await items.save(word);
    for (var index = 0; index < 12; index++) {
      await practice.saveAttempt(
        PracticeAttempt(
          id: 'attempt-$index',
          itemId: word.id,
          sessionId: 'session-1',
          answerText: 'lernen',
          correct: index >= 5,
          attemptedAt: word.createdAt.add(Duration(minutes: index)),
        ),
      );
    }

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();

    expect(find.text('Letzte 10: 7/10 · 70 %'), findsOneWidget);
    expect(find.text('Gesamt: 7/12 · 58 %'), findsOneWidget);
    expect(
      find.byKey(const Key('word-statistics-word-1')),
      findsOneWidget,
    );
  });

  testWidgets('marks important words and clears them only after confirmation', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteLearningItemRepository(database);
    await repository.save(_word());
    await repository.save(_importantWord());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();

    final toggleWord = find.byKey(const Key('toggle-important-word-1')).last;
    await tester.ensureVisible(toggleWord);
    await tester.pumpAndSettle();
    await tester.tap(toggleWord);
    await tester.pumpAndSettle();
    expect((await repository.findById('word-1'))!.isImportant, isTrue);

    await tester.tap(find.byKey(const Key('clear-important-words')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('confirm-clear-important-words')),
      findsOneWidget,
    );
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect((await repository.findById('word-1'))!.isImportant, isTrue);
    expect((await repository.findById('important-word'))!.isImportant, isTrue);

    await tester.tap(find.byKey(const Key('clear-important-words')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-clear-important-words')));
    await tester.pumpAndSettle();

    expect((await repository.findById('word-1'))!.isImportant, isFalse);
    expect(
      (await repository.findById('important-word'))!.isImportant,
      isFalse,
    );
  });

  testWidgets('important practice contains only marked words', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final repository = SqliteLearningItemRepository(database);
    await repository.save(_word());
    await repository.save(_importantWord());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    final start = find.byKey(
      const Key('create-important-to-german-session'),
    );
    await tester.scrollUntilVisible(start, 300);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-prompt')), findsOneWidget);
    expect(find.text('завтра'), findsOneWidget);
    expect(find.text('учить'), findsNothing);
  });

  testWidgets('wechselt die Sprache und behält sie nach einem Neustart', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('language-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
    expect(find.text('Повторение'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(find.text('Сегодня'), findsWidgets);
  });

  testWidgets('sucht, löscht und stellt Material wieder her', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wörter'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('material-search')),
      'Deutsch',
    );
    expect(find.text('lernen'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Wörter'), findsOneWidget);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(find.text('lernen'), findsOneWidget);
  });

  testWidgets('speichert den Fortschritt und zeigt Statistik', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-german');
    await tester.tap(find.byKey(const Key('start-review')));
    await tester.pumpAndSettle();
    expect(find.text('учить'), findsOneWidget);
    expect(find.textContaining('Beispiel:'), findsNothing);

    await tester.enterText(find.byKey(const Key('practice-answer')), 'leren');
    await tester.tap(find.byKey(const Key('check-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Noch nicht richtig'), findsOneWidget);
    expect(find.text('Richtige Antwort: lernen'), findsOneWidget);
    expect(find.text('Beispiel: Ich lerne Deutsch.'), findsOneWidget);
    expect(find.text('Notiz: Wort aus Lektion 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-answer')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('back-to-plan')));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 von 20 Antworten'), findsOneWidget);
    expect(find.text('Fortsetzen'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-german');
    expect(find.textContaining('1 von 20 Antworten'), findsOneWidget);

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gesamt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Problemwörter'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Problemwörter'), findsOneWidget);
    expect(find.text('lernen'), findsOneWidget);
    expect(find.text('1 Fehler · Genauigkeit: 0 %'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);
  });

  testWidgets('shows separate daily statistics for each practice category', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());
    final now = DateTime.now();
    final sessions = await SqliteDailySessionRepository(database).ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
      includeGrammar: true,
    );
    final vocabularySession = sessions.firstWhere(
      (session) => session.kind == DailySessionKind.vocabularyToGerman,
    );
    final numberSession = sessions.firstWhere(
      (session) => session.kind == DailySessionKind.numbers,
    );
    final grammarSession = sessions.firstWhere(
      (session) => session.kind == DailySessionKind.grammar,
    );
    database.connection.execute(
      '''
      INSERT INTO practice_attempts (
        id, item_id, session_id, answer_text, correct, attempted_at
      ) VALUES
        ('word-correct', 'word-1', ?, 'lernen', 1, ?),
        ('word-error', 'word-1', ?, 'leren', 0, ?),
        ('word-old', 'word-1', ?, 'lernen', 1, ?)
      ''',
      <Object?>[
        vocabularySession.id,
        now.toUtc().toIso8601String(),
        vocabularySession.id,
        now.toUtc().toIso8601String(),
        vocabularySession.id,
        now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
      ],
    );
    database.connection.execute(
      '''
      INSERT INTO grammar_attempts (
        id, topic_id, exercise_id, session_id,
        answer_text, correct, attempted_at
      ) VALUES
        ('number-correct', 'numbers', 'number:to_digits:1', ?, '1', 1, ?),
        ('number-error', 'numbers', 'number:to_german:1', ?, '', 0, ?),
        ('number-old', 'numbers', 'number:to_digits:2', ?, '2', 1, ?),
        ('grammar-error', 'sein', 'sein-1', ?, '', 0, ?),
        ('grammar-old', 'haben', 'haben-1', ?, 'habe', 1, ?)
      ''',
      <Object?>[
        numberSession.id,
        now.toUtc().toIso8601String(),
        numberSession.id,
        now.toUtc().toIso8601String(),
        numberSession.id,
        now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
        grammarSession.id,
        now.toUtc().toIso8601String(),
        grammarSession.id,
        now.subtract(const Duration(days: 2)).toUtc().toIso8601String(),
      ],
    );

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();

    void expectCategory(String key, List<String> values) {
      final card = find.byKey(Key(key));
      expect(card, findsOneWidget);
      for (final value in values) {
        expect(find.descendant(of: card, matching: find.text(value)),
            findsOneWidget);
      }
    }

    expectCategory('daily-statistics-words', <String>[
      'Versuche: 2',
      'Richtig: 1',
      'Fehler: 1',
      'Genauigkeit: 50 %',
    ]);
    expectCategory('daily-statistics-numbers', <String>[
      'Versuche: 2',
      'Richtig: 1',
      'Fehler: 1',
      'Genauigkeit: 50 %',
    ]);
    expectCategory('daily-statistics-grammar', <String>[
      'Versuche: 1',
      'Richtig: 0',
      'Fehler: 1',
      'Genauigkeit: 0 %',
    ]);
    expect(find.text('Problemwörter'), findsNothing);

    await tester.tap(find.text('Gesamt'));
    await tester.pumpAndSettle();
    expectCategory('all-time-statistics-words', <String>[
      'Versuche: 3',
      'Richtig: 2',
      'Fehler: 1',
      'Genauigkeit: 67 %',
    ]);
    expectCategory('all-time-statistics-numbers', <String>[
      'Versuche: 3',
      'Richtig: 2',
      'Fehler: 1',
      'Genauigkeit: 67 %',
    ]);
    expectCategory('all-time-statistics-grammar', <String>[
      'Versuche: 2',
      'Richtig: 1',
      'Fehler: 1',
      'Genauigkeit: 50 %',
    ]);
    await tester.scrollUntilVisible(find.text('Problemwörter'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Problemwörter'), findsOneWidget);
  });

  testWidgets('records an unknown vocabulary answer and reveals the solution', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-german');
    await tester.tap(find.byKey(const Key('start-review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unknown-answer')));
    await tester.pumpAndSettle();

    expect(find.text('Richtige Antwort: lernen'), findsOneWidget);
    final attempts = database.connection.select(
      'SELECT answer_text, correct FROM practice_attempts',
    );
    expect(attempts, hasLength(1));
    expect(attempts.single['answer_text'], '');
    expect(attempts.single['correct'], 0);
  });

  testWidgets('accepts any Russian translation in the reverse lesson', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_wordWithTranslations());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-russian');
    await tester.scrollUntilVisible(
      find.text('Wörter auf Russisch · Übung 1'),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('start-review-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-4')));
    await tester.pumpAndSettle();

    expect(find.text('lernen'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('practice-answer')),
      'изучать',
    );
    await tester.tap(find.byKey(const Key('check-answer')));
    await tester.pumpAndSettle();

    expect(find.text('Richtig'), findsOneWidget);
  });

  testWidgets('shows usage examples as help only in the reverse lesson', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_wordWithExamples());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-russian');
    await tester.scrollUntilVisible(
      find.text('Wörter auf Russisch · Übung 1'),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('start-review-4')));
    await tester.tap(find.byKey(const Key('start-review-4')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vocabulary-help')), findsOneWidget);
    expect(find.text('Ich lerne Deutsch.'), findsNothing);
    await tester.tap(find.byKey(const Key('vocabulary-help')));
    await tester.pumpAndSettle();
    expect(find.text('Ich lerne Deutsch.'), findsOneWidget);
    expect(find.text('Wir lernen zusammen.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('back-to-plan')));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-german');
    await tester.tap(find.byKey(const Key('start-review')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('vocabulary-help')), findsNothing);
  });

  testWidgets('adds a rejected Russian translation and records it as correct', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_polishWord());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'vocabulary-to-russian');
    await tester.scrollUntilVisible(
      find.text('Wörter auf Russisch · Übung 1'),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('start-review-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-4')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('practice-answer')),
      'польский',
    );
    await tester.tap(find.byKey(const Key('check-answer')));
    await tester.pumpAndSettle();

    expect(find.text('Noch nicht richtig'), findsOneWidget);
    expect(find.byKey(const Key('accept-russian-translation')), findsOneWidget);
    expect(
      database.connection.select('SELECT * FROM practice_attempts'),
      isEmpty,
    );

    await tester.ensureVisible(
      find.byKey(const Key('accept-russian-translation')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accept-russian-translation')));
    await tester.pumpAndSettle();

    final saved = await SqliteLearningItemRepository(database).findById(
      'word-polish',
    );
    expect(saved?.content['translation_ru'], 'польский язык; польский');
    final attempts = database.connection.select(
      'SELECT answer_text, correct FROM practice_attempts',
    );
    expect(attempts, hasLength(1));
    expect(attempts.single['answer_text'], 'польский');
    expect(attempts.single['correct'], 1);
    expect(find.text('Richtig'), findsOneWidget);
  });

  testWidgets('practices digits in both directions', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'numbers');
    await tester.scrollUntilVisible(find.text('Zahlentraining 1'), 300);
    await tester.ensureVisible(find.byKey(const Key('start-review-7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-7')));
    await tester.pumpAndSettle();

    final queue = (jsonDecode(
      database.connection
          .select('SELECT queue_json FROM daily_sessions WHERE slot = 7')
          .single['queue_json'] as String,
    ) as List<Object?>)
        .cast<String>();
    expect(queue, hasLength(20));
    expect(queue.where((task) => task.contains(':to_digits:')), hasLength(10));
    expect(queue.where((task) => task.contains(':to_german:')), hasLength(10));
    expect(queue.map((task) => task.split(':').last).toSet(), hasLength(10));

    final words = {
      for (var value = 0; value <= 100; value++)
        germanNumberWord(value): '$value',
    };
    final firstPrompt = tester.widget<Text>(
      find.byKey(const Key('number-prompt')),
    );
    await tester.enterText(
      find.byKey(const Key('number-answer')),
      words[firstPrompt.data]!,
    );
    await tester.tap(find.byKey(const Key('check-number-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Richtig'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next-number-answer')));
    await tester.pumpAndSettle();
    final secondPrompt = tester.widget<Text>(
      find.byKey(const Key('number-prompt')),
    );
    final inverse = {for (final entry in words.entries) entry.value: entry.key};
    await tester.enterText(
      find.byKey(const Key('number-answer')),
      inverse[secondPrompt.data]!,
    );
    await tester.tap(find.byKey(const Key('check-number-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Richtig'), findsOneWidget);
  });

  testWidgets('bietet nach fünf Sitzungen einen neuen Unterricht an', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());
    final now = DateTime.now();
    await SqliteDailySessionRepository(database).ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
    );
    database.connection.execute(
      "UPDATE daily_sessions SET status = 'completed', "
      'answered_count = target_answers, completed_at = updated_at '
      'WHERE local_date = ?',
      [localDayKey(now)],
    );

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(find.text('8 von 8 Sitzungen abgeschlossen'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('toggle-session-category-vocabulary-to-german'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('create-extra-session')),
      300,
    );
    expect(find.byKey(const Key('create-extra-session')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-extra-session')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-answer')), findsOneWidget);
  });

  testWidgets('starts the next lesson from a collapsed category header', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key('session-category-progress-vocabulary-to-german'),
      ),
      findsOneWidget,
    );
    expect(find.text('0/3'), findsWidgets);
    expect(find.text('Wörter auf Deutsch · Übung 1'), findsNothing);
    expect(find.text('Nächste Lektion'), findsWidgets);
    await tester.tap(
      find.byKey(
        const Key('session-category-action-vocabulary-to-german'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-answer')), findsOneWidget);
  });

  testWidgets('continues an unfinished lesson from its category header', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());
    final sessions = SqliteDailySessionRepository(database);
    final now = DateTime.now();
    final day = await sessions.ensureDay(
      localDate: localDayKey(now),
      now: now.toUtc(),
    );
    final first = day.firstWhere((session) => session.slot == 1);
    await sessions.start(
      id: first.id,
      queueItemIds: const ['word-1'],
      now: now.toUtc(),
    );

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(find.text('Lektion fortsetzen'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const Key('session-category-action-vocabulary-to-german'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-answer')), findsOneWidget);
  });

  testWidgets('fragt nach einem Nickname und zeigt den Sync-Status', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final controller = SyncController(
      localStore: SqliteSyncStore(database),
      gateway: _EchoSyncGateway(),
      connectivityChanges: const Stream<List<ConnectivityResult>>.empty(),
    );
    addTearDown(controller.dispose);
    await controller.initialize();

    await tester.pumpWidget(_app(database, syncController: controller));
    await tester.pumpAndSettle();

    expect(find.text('Synchronisierung'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sync-nickname')), 'Test_User');
    await tester.tap(find.byKey(const Key('connect-sync')));
    await tester.pumpAndSettle();

    expect(find.text('Synchronisiert'), findsOneWidget);
    expect(controller.nickname, 'test_user');
  });

  testWidgets('activates grammar sessions for a learned verb topic', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final catalog = _grammarCatalog();
    await SqliteLearningItemRepository(database).save(_verb());

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grammatik'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('grammar-topic-regular_present')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('toggle-topic-regular_present')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heute'));
    await tester.pumpAndSettle();
    expect(find.text('0 von 10 Sitzungen abgeschlossen'), findsOneWidget);
    await _expandCategory(tester, 'grammar');
    await tester.scrollUntilVisible(
      find.text('Gemischte Grammatikübung 1'),
      300,
    );
    expect(find.text('Gemischte Grammatikübung 1'), findsOneWidget);
    expect(
      find.textContaining('Regelmäßige Verben im Präsens'),
      findsNWidgets(2),
    );

    await tester.ensureVisible(find.byKey(const Key('start-review-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-9')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('lernen'), findsOneWidget);
    expect(find.byKey(const Key('grammar-form-ich')), findsOneWidget);
  });

  testWidgets('filters grammar topics by learning status', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final catalog = _foundationGrammarCatalog();
    await SqliteGrammarRepository(database).setLearned(
      topicId: 'verb_basics',
      learned: true,
      now: DateTime.now().toUtc(),
    );

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grammatik'));
    await tester.pumpAndSettle();

    expect(find.text('Alle'), findsOneWidget);
    expect(find.text('Nicht gelernt'), findsOneWidget);
    expect(find.text('Gelernt'), findsWidgets);

    await tester.tap(find.text('Nicht gelernt'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('grammar-topic-verb_basics')), findsNothing);
    expect(
      find.byKey(const Key('grammar-topic-sentence_basics')),
      findsOneWidget,
    );

    await tester.tap(find.text('Gelernt').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('grammar-topic-verb_basics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('grammar-topic-sentence_basics')),
      findsNothing,
    );
  });

  testWidgets('offers to add required grammar material without duplicates', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final catalog = _grammarCatalog();

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grammatik'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('grammar-topic-regular_present')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('toggle-topic-regular_present')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-required-material')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add-required-material')));
    await tester.pumpAndSettle();

    final items = await SqliteLearningItemRepository(database).findActive();
    expect(items, hasLength(1));
    expect(items.single.content['german'], 'lernen');
    expect(
      (await SqliteGrammarRepository(database).progress())['regular_present']
          ?.learned,
      isTrue,
    );
  });

  testWidgets('starts a focused lesson directly from grammar theory', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final catalog = _foundationGrammarCatalog();
    await SqliteLearningItemRepository(database).save(_verb());

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grammatik'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('grammar-topic-sentence_basics')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('practice-topic-sentence_basics')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('grammar-word-order-answer')), findsOneWidget);
    final sessions = database.connection.select(
      "SELECT queue_json FROM daily_sessions WHERE kind = 'grammar' "
      'AND slot IS NULL',
    );
    expect(sessions, hasLength(1));
    expect(sessions.single['queue_json'], contains('foundation-order'));
    expect(sessions.single['queue_json'], isNot(contains('foundation-choice')));
  });

  testWidgets('starts reading practice without dictionary material', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final catalog = _readingCatalog();

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grammatik'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Leseregeln: Vokale und Doppellaute'),
      300,
    );
    await tester.tap(
      find.byKey(const Key('grammar-topic-reading_vowels')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Liebe [ˈliːbə]'), findsWidgets);
    await tester.tap(
      find.byKey(const Key('practice-topic-reading_vowels')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('grammar-prompt')), findsOneWidget);
    expect(find.byKey(const Key('check-grammar-answer')), findsOneWidget);
    final sessions = database.connection.select(
      "SELECT queue_json FROM daily_sessions WHERE kind = 'grammar' "
      'AND slot IS NULL',
    );
    expect(sessions, hasLength(1));
    expect(sessions.single['queue_json'], contains('reading-vowels-'));
  });

  testWidgets('shows Russian grammar instructions and answer choices', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_verb());
    await SqliteSettingsRepository(database).saveLanguage(AppLanguage.russian);
    await SqliteGrammarRepository(database).setLearned(
      topicId: 'verb_basics',
      learned: true,
      now: DateTime.now().toUtc(),
    );

    await tester.pumpWidget(
      _app(database, grammarCatalog: _russianChoiceCatalog()),
    );
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'grammar');
    await tester.scrollUntilVisible(
      find.text('Смешанная практика грамматики №1'),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('start-review-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-9')));
    await tester.pumpAndSettle();

    expect(find.text('Определите часть речи.'), findsOneWidget);
    expect(find.text('Глагол'), findsOneWidget);
    expect(find.text('Существительное'), findsOneWidget);
    expect(find.byKey(const Key('unknown-grammar-answer')), findsOneWidget);
  });

  testWidgets('mixes learned foundation topics and supports new answer modes', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    final grammar = SqliteGrammarRepository(database);
    final catalog = _foundationGrammarCatalog();
    await SqliteLearningItemRepository(database).save(_verb());
    final now = DateTime.now().toUtc();
    await grammar.setLearned(
      topicId: 'verb_basics',
      learned: true,
      now: now,
    );
    await grammar.setLearned(
      topicId: 'sentence_basics',
      learned: true,
      now: now,
    );

    await tester.pumpWidget(_app(database, grammarCatalog: catalog));
    await tester.pumpAndSettle();
    await _expandCategory(tester, 'grammar');
    await tester.scrollUntilVisible(
      find.text('Gemischte Grammatikübung 1'),
      300,
    );
    await tester.ensureVisible(find.byKey(const Key('start-review-9')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review-9')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final session = (await SqliteDailySessionRepository(database).ensureDay(
      localDate: localDayKey(DateTime.now()),
      now: DateTime.now().toUtc(),
      includeGrammar: true,
    ))
        .firstWhere((entry) => entry.slot == 9);
    expect(session.queueItemIds.toSet(),
        {'foundation-choice', 'foundation-order'});

    Future<void> answerVisibleExercise() async {
      if (find.byKey(const Key('grammar-option-Verb')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('grammar-option-Verb')));
      } else {
        await tester.tap(find.byKey(const Key('grammar-token-2')));
        await tester.tap(find.byKey(const Key('grammar-token-1')));
        await tester.tap(find.byKey(const Key('grammar-token-0')));
      }
      await tester.tap(find.byKey(const Key('check-grammar-answer')));
      await tester.pump();
      expect(find.text('Richtig'), findsOneWidget);
      await tester.tap(find.byKey(const Key('next-grammar-answer')));
      await tester.pump();
    }

    await answerVisibleExercise();
    await answerVisibleExercise();
    expect(database.connection.select('SELECT * FROM grammar_attempts'),
        hasLength(2));
  });
}

Future<void> _expandCategory(WidgetTester tester, String category) async {
  final toggle = find.byKey(Key('toggle-session-category-$category'));
  await tester.scrollUntilVisible(toggle, 300);
  await tester.pumpAndSettle();
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

DeutschReviewApp _app(
  AppDatabase database, {
  SyncController? syncController,
  GrammarCatalog? grammarCatalog,
}) {
  return DeutschReviewApp(
    learningItems: SqliteLearningItemRepository(database),
    sessions: SqliteDailySessionRepository(database),
    settings: SqliteSettingsRepository(database),
    practice: SqlitePracticeRepository(database),
    grammar: SqliteGrammarRepository(database),
    grammarCatalog: grammarCatalog ??
        GrammarCatalog(
          topics: const [],
          verbs: const [],
          exercises: const [],
        ),
    syncController: syncController,
  );
}

final class _EchoSyncGateway implements SyncGateway {
  @override
  Future<Map<String, Object?>> synchronize({
    required String nickname,
    required Map<String, Object?> localPayload,
  }) async {
    return localPayload;
  }
}

LearningItem _word() {
  final now = DateTime.utc(2026, 9, 23, 10);
  return LearningItem(
    id: 'word-1',
    type: LearningItemType.word,
    level: 'A1.1',
    lesson: '1',
    topic: 'Schule',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'DAA',
    content: const {
      'german': 'lernen',
      'translation_ru': 'учить',
      'example': 'Ich lerne Deutsch.',
      'note': 'Wort aus Lektion 1',
    },
  );
}

LearningItem _importantWord() {
  final now = DateTime.utc(2026, 9, 29, 10);
  return LearningItem(
    id: 'important-word',
    type: LearningItemType.word,
    level: 'A1.1',
    lesson: '2',
    topic: 'Zeit',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'test',
    content: const {
      'german': 'morgen',
      'translation_ru': 'завтра',
      'important': true,
    },
  );
}

LearningItem _wordWithTranslations() {
  final item = _word();
  return LearningItem(
    id: item.id,
    type: item.type,
    level: item.level,
    lesson: item.lesson,
    topic: item.topic,
    learned: item.learned,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    sourceRef: item.sourceRef,
    content: const {
      'german': 'lernen',
      'translation_ru': 'учить; изучать; обучаться',
    },
  );
}

LearningItem _wordWithExamples() {
  final item = _word();
  return LearningItem(
    id: item.id,
    type: item.type,
    level: item.level,
    lesson: item.lesson,
    topic: item.topic,
    learned: item.learned,
    createdAt: item.createdAt,
    updatedAt: item.updatedAt,
    sourceRef: item.sourceRef,
    content: const {
      'german': 'lernen',
      'translation_ru': 'учить',
      'example': 'Ich lerne Deutsch.; Wir lernen zusammen.',
    },
  );
}

LearningItem _polishWord() {
  final now = DateTime.utc(2026, 9, 27, 10);
  return LearningItem(
    id: 'word-polish',
    type: LearningItemType.word,
    level: 'A1.1',
    lesson: '1',
    topic: 'Sprachen',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'test',
    content: const {
      'german': 'Polnisch',
      'translation_ru': 'польский язык',
    },
  );
}

LearningItem _verb() {
  final now = DateTime.utc(2026, 9, 24, 10);
  return LearningItem(
    id: 'verb-lernen',
    type: LearningItemType.verb,
    level: '',
    lesson: '',
    topic: '',
    learned: true,
    createdAt: now,
    updatedAt: now,
    sourceRef: 'manual',
    content: const {'german': 'lernen', 'translation_ru': 'учить'},
  );
}

GrammarCatalog _grammarCatalog() {
  const topic = GrammarTopic(
    id: 'regular_present',
    order: 1,
    titleDe: 'Regelmäßige Verben im Präsens',
    titleRu: 'Регулярные глаголы в Präsens',
    summaryDe: 'Regelmäßige Endungen',
    summaryRu: 'Регулярные окончания',
    explanationDe: ['Erklärung'],
    explanationRu: ['Объяснение'],
    table: [
      ['ich', '-e'],
      ['du', '-st'],
    ],
    trainable: true,
  );
  const verb = GrammarVerb(
    lemma: 'lernen',
    topicId: 'regular_present',
    stem: 'lern',
    forms: {
      'ich': 'lerne',
      'du': 'lernst',
      'er/sie/es': 'lernt',
      'wir': 'lernen',
      'ihr': 'lernt',
      'sie/Sie': 'lernen',
    },
  );
  return GrammarCatalog(
    topics: const [topic],
    verbs: const [verb],
    exercises: List.generate(
      12,
      (index) => GrammarExercise(
        id: 'exercise-$index',
        topicId: 'regular_present',
        lemma: 'lernen',
        prompt: 'Ich lern_ Beispiel $index.',
        answer: 'e',
      ),
    ),
  );
}

GrammarCatalog _foundationGrammarCatalog() {
  const choiceTopic = GrammarTopic(
    id: 'verb_basics',
    order: 1,
    titleDe: 'Was ist ein Verb?',
    titleRu: 'Что такое глагол',
    summaryDe: 'Wortart',
    summaryRu: 'Часть речи',
    explanationDe: ['Erklärung'],
    explanationRu: ['Объяснение'],
    table: [],
    trainable: true,
  );
  const orderTopic = GrammarTopic(
    id: 'sentence_basics',
    order: 2,
    titleDe: 'Der einfache Satz',
    titleRu: 'Простое предложение',
    summaryDe: 'Wortstellung',
    summaryRu: 'Порядок слов',
    explanationDe: ['Erklärung'],
    explanationRu: ['Объяснение'],
    table: [],
    trainable: true,
  );
  return GrammarCatalog(
    topics: const [choiceTopic, orderTopic],
    verbs: const [],
    exercises: const [
      GrammarExercise(
        id: 'foundation-choice',
        topicId: 'verb_basics',
        lemma: 'lernen',
        prompt: 'Welche Wortart ist „lernen“?',
        answer: 'Verb',
        type: GrammarExerciseType.choice,
        options: ['Nomen', 'Verb'],
      ),
      GrammarExercise(
        id: 'foundation-order',
        topicId: 'sentence_basics',
        lemma: 'lernen',
        prompt: 'Ordne die Wörter.',
        answer: 'Ich lerne heute.',
        type: GrammarExerciseType.wordOrder,
        options: ['heute.', 'lerne', 'Ich'],
      ),
    ],
  );
}

GrammarCatalog _russianChoiceCatalog() {
  const topic = GrammarTopic(
    id: 'verb_basics',
    order: 1,
    titleDe: 'Was ist ein Verb?',
    titleRu: 'Что такое глагол',
    summaryDe: 'Wortart',
    summaryRu: 'Часть речи',
    explanationDe: ['Erklärung'],
    explanationRu: ['Объяснение'],
    table: [],
    trainable: true,
  );
  return GrammarCatalog(
    topics: const [topic],
    verbs: const [],
    exercises: const [
      GrammarExercise(
        id: 'russian-choice',
        topicId: 'verb_basics',
        lemma: 'lernen',
        prompt: 'Welche Wortart ist „lernen“?',
        answer: 'Verb',
        type: GrammarExerciseType.choice,
        options: ['Nomen', 'Verb'],
        instructionDe: 'Bestimme die Wortart.',
        instructionRu: 'Определите часть речи.',
      ),
    ],
  );
}

GrammarCatalog _readingCatalog() {
  const topic = GrammarTopic(
    id: 'reading_vowels',
    order: -4,
    titleDe: 'Leseregeln: Vokale und Doppellaute',
    titleRu: 'Правила чтения: гласные и дифтонги',
    summaryDe: 'Vokale lesen',
    summaryRu: 'Чтение гласных',
    explanationDe: ['ie: Liebe [ˈliːbə]'],
    explanationRu: ['ie: Liebe [ˈliːbə]'],
    table: [],
    trainable: true,
  );
  return GrammarCatalog(
    topics: const [topic],
    verbs: const [],
    exercises: List.generate(
      20,
      (index) => GrammarExercise(
        id: 'reading-vowels-$index',
        topicId: 'reading_vowels',
        lemma: 'reading',
        prompt: 'Liebe: ie = ?',
        answer: '[iː]',
        type: GrammarExerciseType.choice,
        requiredItemType: 'none',
        options: const ['[iː]', '[ɪ]'],
      ),
    ),
  );
}
