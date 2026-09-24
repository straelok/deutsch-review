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
}
