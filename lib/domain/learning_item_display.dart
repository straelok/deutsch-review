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
