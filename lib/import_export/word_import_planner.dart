import '../domain/learning_item.dart';
import '../domain/learning_item_display.dart';

final class WordImportPlan {
  const WordImportPlan({
    required this.additions,
    required this.updates,
    required this.skipped,
  });

  final List<LearningItem> additions;
  final List<LearningItem> updates;
  final int skipped;

  List<LearningItem> get itemsToSave => [...additions, ...updates];
}

WordImportPlan planWordImport({
  required List<LearningItem> existing,
  required List<LearningItem> imported,
  required DateTime importedAt,
}) {
  final existingById = <String, LearningItem>{
    for (final item in existing) item.id: item,
  };
  final existingByKey = <String, LearningItem>{
    for (final item in existing.where((item) => item.deletedAt == null))
      wordImportKey(item): item,
  };
  final seenIds = <String>{};
  final seenKeys = <String>{};
  final additions = <LearningItem>[];
  final updates = <LearningItem>[];
  var skipped = 0;

  for (final incoming in imported) {
    final key = wordImportKey(incoming);
    if (!seenIds.add(incoming.id) || !seenKeys.add(key)) {
      skipped++;
      continue;
    }

    final byId = existingById[incoming.id];
    final byKey = existingByKey[key];
    if (byId != null && byKey != null && byId.id != byKey.id) {
      skipped++;
      continue;
    }
    final current = byId ?? byKey;
    if (current == null) {
      additions.add(incoming);
      existingById[incoming.id] = incoming;
      existingByKey[key] = incoming;
      continue;
    }

    final replacementContent = <String, Object?>{
      ...incoming.content,
      if (!incoming.content.containsKey('important') && current.isImportant)
        'important': true,
    };
    final replacement = LearningItem(
      id: current.id,
      type: incoming.type,
      level: current.level,
      lesson: current.lesson,
      topic: current.topic,
      learned: current.learned,
      createdAt: current.createdAt,
      updatedAt: importedAt.toUtc(),
      sourceRef: 'json',
      content: replacementContent,
    );
    if (current.deletedAt == null &&
        current.type == replacement.type &&
        _sameContent(current.content, replacement.content)) {
      skipped++;
      continue;
    }

    updates.add(replacement);
    existingById[current.id] = replacement;
    existingByKey.remove(wordImportKey(current));
    existingByKey[key] = replacement;
  }

  return WordImportPlan(
    additions: List.unmodifiable(additions),
    updates: List.unmodifiable(updates),
    skipped: skipped,
  );
}

String wordImportKey(LearningItem item) =>
    '${item.type.wireName}:${learningItemGerman(item).trim()}';

bool _sameContent(Map<String, Object?> left, Map<String, Object?> right) {
  if (left.length != right.length) return false;
  return left.entries.every((entry) => right[entry.key] == entry.value);
}
