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

  test('accepts any semicolon-separated Russian translation', () {
    expect(
      isAnyPracticeAnswerCorrect(
        answer: 'изучать',
        expectedAlternatives: 'учить; изучать; обучаться',
      ),
      isTrue,
    );
    expect(
      isAnyPracticeAnswerCorrect(
        answer: 'ЕЛКА',
        expectedAlternatives: 'дерево; ёлка',
      ),
      isTrue,
    );
    expect(
      isAnyPracticeAnswerCorrect(
        answer: 'учиться',
        expectedAlternatives: 'учить; изучать; обучаться',
      ),
      isFalse,
    );
  });

  test('appends one normalized Russian answer without duplicates', () {
    expect(
      appendRussianPracticeAnswerAlternative(
        expectedAlternatives: 'польский язык',
        answer: '  польский  ',
      ),
      'польский язык; польский',
    );
    expect(
      appendRussianPracticeAnswerAlternative(
        expectedAlternatives: 'дерево; ёлка',
        answer: 'ЕЛКА',
      ),
      'дерево; ёлка',
    );
  });
}
