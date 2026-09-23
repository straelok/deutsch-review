import 'package:deutsch_review/app.dart';
import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_practice_repository.dart';
import 'package:deutsch_review/data/repositories/sqlite_settings_repository.dart';
import 'package:deutsch_review/domain/learning_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigiert zum leeren Materialbereich', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();

    expect(
      find.text('Für heute sind noch keine Wiederholungen geplant.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Wörter'), findsOneWidget);
    expect(find.text('0 Einträge aus deinem DAA-Kurs'), findsOneWidget);
  });

  testWidgets('fügt ein Wort hinzu und bearbeitet es', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-material')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('german')), 'lernen');
    await tester.enterText(find.byKey(const Key('translation')), 'учить');
    expect(find.text('Niveau'), findsNothing);
    expect(find.text('Lektion'), findsNothing);
    expect(find.text('Thema'), findsNothing);
    expect(find.text('Quelle'), findsNothing);
    expect(find.text('Im Kurs gelernt'), findsNothing);
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('lernen'), findsOneWidget);
    expect(find.text('1 Einträge aus deinem DAA-Kurs'), findsOneWidget);
    expect(find.textContaining('Hinzugefügt:'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('german')), 'wiederholen');
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('wiederholen'), findsOneWidget);
    expect(find.text('lernen'), findsNothing);
  });

  testWidgets('fügt ein Nomen mit Artikel und Plural hinzu', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material'));
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
    expect(find.text('Повторение'), findsOneWidget);

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
    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('material-search')),
      'учить',
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

  testWidgets('prüft Antworten automatisch und zeigt Statistik', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);
    await SqliteLearningItemRepository(database).save(_word());

    await tester.pumpWidget(_app(database));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lernen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('start-review')));
    await tester.pumpAndSettle();
    expect(find.text('учить'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('practice-answer')), 'leren');
    await tester.tap(find.byKey(const Key('check-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Noch nicht richtig'), findsOneWidget);
    expect(find.text('Richtige Antwort: lernen'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-answer')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('practice-answer')), 'lernen');
    await tester.tap(find.byKey(const Key('check-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Richtig'), findsOneWidget);
    await tester.tap(find.byKey(const Key('next-answer')));
    await tester.pumpAndSettle();
    expect(find.text('Sitzung abgeschlossen'), findsOneWidget);

    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Problemwörter'), findsOneWidget);
    expect(find.text('lernen'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
}

DeutschReviewApp _app(AppDatabase database) {
  return DeutschReviewApp(
    learningItems: SqliteLearningItemRepository(database),
    settings: SqliteSettingsRepository(database),
    practice: SqlitePracticeRepository(database),
  );
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
    content: const {'german': 'lernen', 'translation_ru': 'учить'},
  );
}
