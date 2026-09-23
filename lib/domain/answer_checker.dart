String normalizePracticeAnswer(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

bool isPracticeAnswerCorrect({
  required String answer,
  required String expected,
}) {
  return normalizePracticeAnswer(answer) == normalizePracticeAnswer(expected);
}
