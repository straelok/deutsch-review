import 'package:deutsch_review/domain/answer_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ignores surrounding and repeated whitespace', () {
    expect(
      isPracticeAnswerCorrect(answer: '  der   Tisch ', expected: 'der Tisch'),
      isTrue,
    );
  });

  test('keeps meaningful German differences', () {
    expect(
      isPracticeAnswerCorrect(answer: 'Tisch', expected: 'der Tisch'),
      isFalse,
    );
    expect(
      isPracticeAnswerCorrect(answer: 'Der Tisch', expected: 'der Tisch'),
      isFalse,
    );
    expect(
      isPracticeAnswerCorrect(answer: 'schon', expected: 'schön'),
      isFalse,
    );
  });
}
