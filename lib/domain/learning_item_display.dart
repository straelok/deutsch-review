import 'learning_item.dart';

String learningItemGerman(LearningItem item) {
  final german = item.content['german'] as String? ?? '';
  final article = item.content['article'] as String?;
  if (item.type == LearningItemType.noun && article != null) {
    return '$article $german';
  }
  return german;
}

String learningItemMeaning(LearningItem item) {
  return item.content['translation_ru'] as String? ?? '';
}

String learningItemGermanWithPlural(LearningItem item) {
  final german = learningItemGerman(item);
  if (item.type != LearningItemType.noun) return german;

  final singular = item.content['german'] as String? ?? '';
  final plural = _optionalText(item.content['plural']);
  if (singular.isEmpty || plural == null) return german;
  return '$german, ${_compactPlural(singular, plural)}';
}

String? learningItemNote(LearningItem item) {
  return _optionalText(item.content['note']);
}

String? learningItemExample(LearningItem item) {
  return _optionalText(item.content['example']);
}

String? _optionalText(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

String _compactPlural(String singular, String plural) {
  if (plural == '—' || plural == '–') return plural;
  if (plural == singular) return '-';

  final normalizedSingular = _withoutUmlauts(singular);
  final normalizedPlural = _withoutUmlauts(plural);
  if (normalizedPlural.startsWith(normalizedSingular)) {
    final changedToUmlaut =
        List<int>.generate(singular.length, (index) => index).any(
      (index) =>
          singular[index] != plural[index] &&
          _withoutUmlauts(singular[index]) == _withoutUmlauts(plural[index]),
    );
    final suffix = plural.substring(singular.length);
    return '${changedToUmlaut ? '-̈' : '-'}$suffix';
  }

  return 'die $plural';
}

String _withoutUmlauts(String value) => value
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('Ä', 'A')
    .replaceAll('Ö', 'O')
    .replaceAll('Ü', 'U');
