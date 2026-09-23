import 'package:deutsch_review/app.dart';
import 'package:deutsch_review/data/database/app_database.dart';
import 'package:deutsch_review/data/repositories/sqlite_learning_item_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigiert zum leeren Materialbereich', (tester) async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    await tester.pumpWidget(
      DeutschReviewApp(
        repository: SqliteLearningItemRepository(database),
      ),
    );
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

    await tester.pumpWidget(
      DeutschReviewApp(
        repository: SqliteLearningItemRepository(database),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-material')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('german')), 'lernen');
    await tester.enterText(find.byKey(const Key('translation')), 'учить');
    await tester.enterText(find.byKey(const Key('lesson')), '2');
    await tester.enterText(find.byKey(const Key('topic')), 'Schule');
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('lernen'), findsOneWidget);
    expect(find.text('1 Einträge aus deinem DAA-Kurs'), findsOneWidget);

    await tester.tap(find.byTooltip('Bearbeiten'));
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

    await tester.pumpWidget(
      DeutschReviewApp(
        repository: SqliteLearningItemRepository(database),
      ),
    );
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
    await tester.enterText(find.byKey(const Key('lesson')), '2');
    await tester.enterText(find.byKey(const Key('topic')), 'Gegenstände');
    await tester.tap(find.byKey(const Key('save-material')));
    await tester.pumpAndSettle();

    expect(find.text('der Tisch'), findsOneWidget);
    expect(find.textContaining('стол'), findsOneWidget);
  });
}
