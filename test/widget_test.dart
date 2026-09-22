import 'package:deutsch_review/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startet auf der Heute-Seite und navigiert zu Material', (
    tester,
  ) async {
    await tester.pumpWidget(const DeutschReviewApp());

    expect(find.text('Für heute sind noch keine Wiederholungen geplant.'),
        findsOneWidget);

    await tester.tap(find.text('Material'));
    await tester.pumpAndSettle();

    expect(find.text('Du hast noch kein Lernmaterial hinzugefügt.'),
        findsOneWidget);
  });
}
