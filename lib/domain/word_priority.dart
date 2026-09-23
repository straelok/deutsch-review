import 'dart:math';

int wordSuccessPercent(List<bool> recentOutcomes) {
  if (recentOutcomes.isEmpty) return 0;
  final correct = recentOutcomes.where((outcome) => outcome).length;
  return (correct * 100 / recentOutcomes.length).round();
}

int wordSelectionWeight(List<bool> recentOutcomes) {
  final success = wordSuccessPercent(recentOutcomes) / 100;
  return 1 + ((1 - success) * 9).round();
}

List<String> buildWeightedQueue({
  required List<String> itemIds,
  required Map<String, List<bool>> recentOutcomes,
  required int length,
  required Random random,
  String? previousItemId,
}) {
  if (itemIds.isEmpty || length <= 0) return const [];
  final queue = <String>[];
  var previous = previousItemId;

  for (var index = 0; index < length; index++) {
    final candidates = itemIds.length == 1
        ? itemIds
        : itemIds.where((id) => id != previous).toList(growable: false);
    final weights = candidates
        .map((id) => wordSelectionWeight(recentOutcomes[id] ?? const []))
        .toList(growable: false);
    final total = weights.fold<int>(0, (sum, weight) => sum + weight);
    var selection = random.nextInt(total);
    var selected = candidates.last;
    for (var candidateIndex = 0;
        candidateIndex < candidates.length;
        candidateIndex++) {
      selection -= weights[candidateIndex];
      if (selection < 0) {
        selected = candidates[candidateIndex];
        break;
      }
    }
    queue.add(selected);
    previous = selected;
  }
  return queue;
}
