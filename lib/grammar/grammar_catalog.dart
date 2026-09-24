import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/grammar.dart';

final class GrammarCatalog {
  GrammarCatalog({
    required List<GrammarTopic> topics,
    required List<GrammarVerb> verbs,
    required List<GrammarExercise> exercises,
  })  : topics = List.unmodifiable(topics),
        verbs = List.unmodifiable(verbs),
        exercises = List.unmodifiable(exercises),
        _verbsByLemma = {for (final verb in verbs) verb.lemma: verb},
        _exercisesById = {
          for (final exercise in exercises) exercise.id: exercise,
        };

  final List<GrammarTopic> topics;
  final List<GrammarVerb> verbs;
  final List<GrammarExercise> exercises;
  final Map<String, GrammarVerb> _verbsByLemma;
  final Map<String, GrammarExercise> _exercisesById;

  static Future<GrammarCatalog> load(AssetBundle bundle) async {
    final content = jsonDecode(
      await bundle.loadString('assets/grammar/topics.json'),
    );
    final exerciseData = jsonDecode(
      await bundle.loadString('assets/grammar/exercises.json'),
    );
    if (content is! Map<String, Object?> ||
        exerciseData is! Map<String, Object?> ||
        content['topics'] is! List ||
        content['verbs'] is! List ||
        exerciseData['exercises'] is! List) {
      throw const FormatException('Invalid grammar catalog.');
    }
    return GrammarCatalog(
      topics: (content['topics'] as List)
          .map((value) => _topic(_map(value)))
          .toList(growable: false),
      verbs: (content['verbs'] as List)
          .map((value) => _verb(_map(value)))
          .toList(growable: false),
      exercises: (exerciseData['exercises'] as List)
          .map((value) => _exercise(_map(value)))
          .toList(growable: false),
    );
  }

  GrammarVerb? verb(String lemma) => _verbsByLemma[normalizeLemma(lemma)];

  GrammarExercise? exercise(String id) => _exercisesById[id];

  List<GrammarExercise> exercisesFor({
    required String topicId,
    required Set<String> activeLemmas,
  }) {
    return exercises
        .where(
          (exercise) =>
              exercise.topicId == topicId &&
              activeLemmas.contains(exercise.lemma),
        )
        .toList(growable: false);
  }

  List<GrammarVerb> verbsFor({
    required String topicId,
    required Set<String> activeLemmas,
  }) {
    return verbs
        .where(
          (verb) =>
              verb.topicId == topicId && activeLemmas.contains(verb.lemma),
        )
        .toList(growable: false);
  }

  Set<String> availableTopicIds({
    required Set<String> learnedTopicIds,
    required Set<String> activeLemmas,
  }) {
    return topics
        .where((topic) => topic.trainable && learnedTopicIds.contains(topic.id))
        .where(
          (topic) => verbsFor(
            topicId: topic.id,
            activeLemmas: activeLemmas,
          ).isNotEmpty,
        )
        .map((topic) => topic.id)
        .toSet();
  }

  static String normalizeLemma(String value) => value.trim().toLowerCase();

  static GrammarTopic _topic(Map<String, Object?> json) => GrammarTopic(
        id: _string(json, 'id'),
        order: _int(json, 'order'),
        titleDe: _string(json, 'title_de'),
        titleRu: _string(json, 'title_ru'),
        summaryDe: _string(json, 'summary_de'),
        summaryRu: _string(json, 'summary_ru'),
        explanationDe: _strings(json, 'explanation_de'),
        explanationRu: _strings(json, 'explanation_ru'),
        table: (_list(json, 'table'))
            .map((row) => (row as List).cast<String>())
            .toList(growable: false),
        trainable: json['trainable'] == true,
      );

  static GrammarVerb _verb(Map<String, Object?> json) {
    final rawForms = json['forms'];
    if (rawForms is! Map) throw const FormatException('Invalid verb forms.');
    return GrammarVerb(
      lemma: normalizeLemma(_string(json, 'lemma')),
      topicId: _string(json, 'topic_id'),
      stem: _string(json, 'stem'),
      forms: rawForms.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

  static GrammarExercise _exercise(Map<String, Object?> json) =>
      GrammarExercise(
        id: _string(json, 'id'),
        topicId: _string(json, 'topic_id'),
        lemma: normalizeLemma(_string(json, 'lemma')),
        prompt: _string(json, 'prompt'),
        answer: _string(json, 'answer'),
      );

  static Map<String, Object?> _map(Object? value) {
    if (value is! Map) throw const FormatException('Expected an object.');
    return value.map(
      (key, item) => MapEntry(key.toString(), item as Object?),
    );
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string.');
    return value;
  }

  static int _int(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List) throw FormatException('$key must be a list.');
    return value;
  }

  static List<String> _strings(Map<String, Object?> json, String key) =>
      _list(json, key).cast<String>();
}
