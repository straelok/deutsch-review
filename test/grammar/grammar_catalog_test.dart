import 'package:deutsch_review/grammar/grammar_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the static grammar bank with one thousand regular examples',
      () async {
    final catalog = await GrammarCatalog.load(rootBundle);

    expect(
      catalog.exercises
          .where((exercise) => exercise.topicId == 'regular_present'),
      hasLength(1000),
    );
    expect(
      catalog.exercises.where((exercise) => exercise.topicId == 'sein'),
      hasLength(80),
    );
    expect(
      catalog.exercises.where((exercise) => exercise.topicId == 'haben'),
      hasLength(80),
    );
    expect(catalog.exercise('regular-0001')?.answer, 'e');
    expect(catalog.verb('sein')?.forms['du'], 'bist');
    expect(catalog.topics.any((topic) => topic.id == 'alphabet'), isTrue);
    expect(catalog.topics.any((topic) => topic.id == 'numbers'), isTrue);
    expect(
      catalog.topics.every(
        (topic) =>
            topic.explanationDe.length >= 4 &&
            topic.explanationRu.length >= 4 &&
            topic.table.isNotEmpty,
      ),
      isTrue,
    );
    final numbers = catalog.topics.singleWhere(
      (topic) => topic.id == 'numbers',
    );
    expect(numbers.table.expand((row) => row), contains('100'));
    expect(numbers.table.expand((row) => row).join(' '), contains('IPA'));
    final regular = catalog.exercises
        .where((exercise) => exercise.topicId == 'regular_present')
        .toList();
    expect(regular.map((exercise) => exercise.prompt).toSet(), hasLength(1000));
    expect(
      regular.every(
        (exercise) =>
            exercise.prompt.contains('_') &&
            const {'e', 'st', 't', 'en'}.contains(exercise.answer),
      ),
      isTrue,
    );
    for (final verb
        in catalog.verbs.where((verb) => verb.topicId == 'regular_present')) {
      expect(
        regular.where((exercise) => exercise.lemma == verb.lemma),
        hasLength(40),
      );
    }

    final trainableTopics = catalog.topics
        .where((topic) => topic.trainable)
        .map((topic) => topic.id)
        .toSet();
    expect(trainableTopics, hasLength(19));
    for (final topicId in trainableTopics) {
      expect(
        catalog.exercises.where((exercise) => exercise.topicId == topicId),
        hasLength(greaterThanOrEqualTo(20)),
        reason: '$topicId must have a useful static exercise bank',
      );
    }
    expect(
      catalog.exercises.where((exercise) => exercise.type.name == 'wordOrder'),
      isNotEmpty,
    );
    expect(
      catalog.exercises.where((exercise) => exercise.type.name == 'yesNo'),
      isNotEmpty,
    );
    expect(
      catalog.exercises
          .where(
            (exercise) =>
                exercise.options.isNotEmpty &&
                exercise.type.name != 'wordOrder',
          )
          .every((exercise) => exercise.options.contains(exercise.answer)),
      isTrue,
    );
  });

  test('offers reading exercises without dictionary prerequisites', () async {
    final catalog = await GrammarCatalog.load(rootBundle);

    expect(
      catalog.availableTopicIds(
        learnedTopicIds: {
          'reading_vowels',
          'reading_consonants',
          'reading_stress',
        },
      ),
      {'reading_vowels', 'reading_consonants', 'reading_stress'},
    );
    for (final topicId in const {
      'reading_vowels',
      'reading_consonants',
      'reading_stress',
    }) {
      expect(
        catalog.exercises.where((exercise) => exercise.topicId == topicId),
        hasLength(20),
      );
    }
  });

  test('activates only learned topics with a matching active verb', () async {
    final catalog = await GrammarCatalog.load(rootBundle);

    expect(
      catalog.availableTopicIds(
        learnedTopicIds: {'regular_present', 'sein'},
        activeLemmas: {'lernen'},
      ),
      {'regular_present'},
    );
  });

  test('activates foundation topics by matching dictionary item type',
      () async {
    final catalog = await GrammarCatalog.load(rootBundle);

    expect(
      catalog.availableTopicIds(
        learnedTopicIds: {'articles', 'prepositions', 'verb_basics'},
        activeItemKeys: {'noun:tisch', 'word:in', 'verb:lernen'},
      ),
      {'articles', 'prepositions', 'verb_basics'},
    );
    expect(
      catalog.availableTopicIds(
        learnedTopicIds: {'articles'},
        activeItemKeys: {'verb:lernen'},
      ),
      isEmpty,
    );
  });
}
