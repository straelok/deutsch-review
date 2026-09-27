String normalizePracticeAnswer(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeRussianPracticeAnswer(String value) {
  return normalizePracticeAnswer(value).toLowerCase().replaceAll('ё', 'е');
}

bool isPracticeAnswerCorrect({
  required String answer,
  required String expected,
}) {
  return normalizePracticeAnswer(answer) == normalizePracticeAnswer(expected);
}

bool isAnyPracticeAnswerCorrect({
  required String answer,
  required String expectedAlternatives,
}) {
  final normalizedAnswer = normalizeRussianPracticeAnswer(answer);
  return expectedAlternatives
      .split(';')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .map(normalizeRussianPracticeAnswer)
      .contains(normalizedAnswer);
}

String appendRussianPracticeAnswerAlternative({
  required String expectedAlternatives,
  required String answer,
}) {
  final candidate = normalizePracticeAnswer(answer);
  if (candidate.isEmpty || candidate.contains(';')) {
    throw ArgumentError.value(
        answer, 'answer', 'Expected one non-empty answer');
  }
  final alternatives = expectedAlternatives
      .split(';')
      .map(normalizePracticeAnswer)
      .where((value) => value.isNotEmpty)
      .toList(growable: true);
  final normalizedCandidate = normalizeRussianPracticeAnswer(candidate);
  final alreadyIncluded = alternatives
      .map(normalizeRussianPracticeAnswer)
      .contains(normalizedCandidate);
  if (!alreadyIncluded) alternatives.add(candidate);
  return alternatives.join('; ');
}
