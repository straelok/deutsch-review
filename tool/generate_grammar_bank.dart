import 'dart:convert';
import 'dart:io';

const _subjects = <({String text, String key, String ending})>[
  (text: 'Ich', key: 'ich', ending: 'e'),
  (text: 'Du', key: 'du', ending: 'st'),
  (text: 'Er', key: 'er/sie/es', ending: 't'),
  (text: 'Lara', key: 'er/sie/es', ending: 't'),
  (text: 'Wir', key: 'wir', ending: 'en'),
  (text: 'Ihr', key: 'ihr', ending: 't'),
  (text: 'Die Freunde', key: 'sie/Sie', ending: 'en'),
  (text: 'Sie', key: 'sie/Sie', ending: 'en'),
];

const _regular = <String, ({String stem, List<String> tails})>{
  'lernen': (
    stem: 'lern',
    tails: [
      'Deutsch.',
      'neue Wörter.',
      'für den Test.',
      'jeden Abend.',
      'zusammen.'
    ]
  ),
  'machen': (
    stem: 'mach',
    tails: [
      'die Hausaufgaben.',
      'heute Sport.',
      'eine Pause.',
      'das Frühstück.',
      'alles allein.'
    ]
  ),
  'wohnen': (
    stem: 'wohn',
    tails: [
      'in Berlin.',
      'bei der Familie.',
      'im Zentrum.',
      'in einer Wohnung.',
      'schon lange hier.'
    ]
  ),
  'kommen': (
    stem: 'komm',
    tails: [
      'aus Polen.',
      'heute später.',
      'um acht Uhr.',
      'mit dem Bus.',
      'aus der Schule.'
    ]
  ),
  'leben': (
    stem: 'leb',
    tails: [
      'in Deutschland.',
      'allein.',
      'mit der Familie.',
      'sehr ruhig.',
      'in einer großen Stadt.'
    ]
  ),
  'kaufen': (
    stem: 'kauf',
    tails: [
      'frisches Brot.',
      'zwei Äpfel.',
      'eine Fahrkarte.',
      'heute Gemüse.',
      'ein neues Heft.'
    ]
  ),
  'spielen': (
    stem: 'spiel',
    tails: [
      'gern Fußball.',
      'heute Karten.',
      'mit den Kindern.',
      'am Wochenende Schach.',
      'ein neues Spiel.'
    ]
  ),
  'hören': (
    stem: 'hör',
    tails: [
      'gern Musik.',
      'den Lehrer.',
      'jeden Morgen Radio.',
      'die Frage.',
      'eine interessante Geschichte.'
    ]
  ),
  'fragen': (
    stem: 'frag',
    tails: [
      'den Lehrer.',
      'nach dem Namen.',
      'nach dem Weg.',
      'die Kollegin.',
      'noch einmal.'
    ]
  ),
  'sagen': (
    stem: 'sag',
    tails: [
      'den Namen.',
      'die Wahrheit.',
      'freundlich Hallo.',
      'die richtige Antwort.',
      'einen kurzen Satz.'
    ]
  ),
  'glauben': (
    stem: 'glaub',
    tails: [
      'an den Erfolg.',
      'diese Geschichte.',
      'an eine gute Lösung.',
      'dem Lehrer.',
      'an morgen.'
    ]
  ),
  'brauchen': (
    stem: 'brauch',
    tails: [
      'mehr Zeit.',
      'einen Stift.',
      'heute Hilfe.',
      'eine kurze Pause.',
      'noch ein Beispiel.'
    ]
  ),
  'kochen': (
    stem: 'koch',
    tails: [
      'heute Suppe.',
      'gern zusammen.',
      'am Abend Reis.',
      'für die Familie.',
      'eine warme Mahlzeit.'
    ]
  ),
  'grillen': (
    stem: 'grill',
    tails: [
      'im Garten.',
      'am Wochenende.',
      'Gemüse und Fisch.',
      'mit den Freunden.',
      'heute Abend.'
    ]
  ),
  'frühstücken': (
    stem: 'frühstück',
    tails: [
      'um sieben Uhr.',
      'gern zu Hause.',
      'heute zusammen.',
      'am Wochenende spät.',
      'mit Kaffee und Brot.'
    ]
  ),
  'fotografieren': (
    stem: 'fotografier',
    tails: [
      'die Familie.',
      'gern die Stadt.',
      'das schöne Haus.',
      'im Urlaub viel.',
      'heute den Garten.'
    ]
  ),
  'telefonieren': (
    stem: 'telefonier',
    tails: [
      'mit der Familie.',
      'am Abend.',
      'mit dem Büro.',
      'heute lange.',
      'in der Pause.'
    ]
  ),
  'studieren': (
    stem: 'studier',
    tails: [
      'in Berlin.',
      'Deutsch und Geschichte.',
      'an der Universität.',
      'jeden Tag viel.',
      'gern zusammen.'
    ]
  ),
  'suchen': (
    stem: 'such',
    tails: [
      'den Schlüssel.',
      'eine neue Wohnung.',
      'die richtige Seite.',
      'heute Arbeit.',
      'im Internet.'
    ]
  ),
  'besuchen': (
    stem: 'besuch',
    tails: [
      'die Familie.',
      'einen Deutschkurs.',
      'heute die Freunde.',
      'am Sonntag das Museum.',
      'die Schule.'
    ]
  ),
  'lieben': (
    stem: 'lieb',
    tails: [
      'gute Musik.',
      'die Familie.',
      'den Sommer.',
      'frisches Brot.',
      'diese Stadt.'
    ]
  ),
  'zeigen': (
    stem: 'zeig',
    tails: [
      'den Weg.',
      'ein Foto.',
      'die neue Wohnung.',
      'die richtige Seite.',
      'heute die Aufgabe.'
    ]
  ),
  'erklären': (
    stem: 'erklär',
    tails: [
      'die Aufgabe.',
      'das neue Wort.',
      'den Weg.',
      'die Regel.',
      'alles langsam.'
    ]
  ),
  'üben': (
    stem: 'üb',
    tails: [
      'jeden Tag Deutsch.',
      'die Aussprache.',
      'neue Sätze.',
      'heute die Grammatik.',
      'zusammen für den Test.'
    ]
  ),
  'bezahlen': (
    stem: 'bezahl',
    tails: [
      'die Rechnung.',
      'mit Karte.',
      'den Kaffee.',
      'an der Kasse.',
      'heute das Essen.'
    ]
  ),
};

const _seinTails = [
  'müde.',
  'heute zu Hause.',
  'pünktlich.',
  'sehr freundlich.',
  'im Deutschkurs.',
  'aus Berlin.',
  'jetzt bereit.',
  'am Wochenende frei.',
  'hier richtig.',
  'sehr ruhig.'
];

const _habenTails = [
  'heute Zeit.',
  'einen Termin.',
  'zwei Kinder.',
  'eine Frage.',
  'großen Hunger.',
  'ein neues Buch.',
  'am Montag frei.',
  'eine gute Idee.',
  'jetzt Unterricht.',
  'viel Arbeit.'
];

const _nouns = <({String lemma, String article, String plural})>[
  (lemma: 'Tisch', article: 'der', plural: 'Tische'),
  (lemma: 'Stuhl', article: 'der', plural: 'Stühle'),
  (lemma: 'Mann', article: 'der', plural: 'Männer'),
  (lemma: 'Apfel', article: 'der', plural: 'Äpfel'),
  (lemma: 'Kaffee', article: 'der', plural: 'Kaffees'),
  (lemma: 'Frau', article: 'die', plural: 'Frauen'),
  (lemma: 'Schule', article: 'die', plural: 'Schulen'),
  (lemma: 'Lampe', article: 'die', plural: 'Lampen'),
  (lemma: 'Frage', article: 'die', plural: 'Fragen'),
  (lemma: 'Wohnung', article: 'die', plural: 'Wohnungen'),
  (lemma: 'Haus', article: 'das', plural: 'Häuser'),
  (lemma: 'Buch', article: 'das', plural: 'Bücher'),
  (lemma: 'Kind', article: 'das', plural: 'Kinder'),
  (lemma: 'Auto', article: 'das', plural: 'Autos'),
  (lemma: 'Brot', article: 'das', plural: 'Brote'),
];

const _describingWords = <({String lemma, String kind, String example})>[
  (lemma: 'klein', kind: 'Adjektiv', example: 'ein kleines Haus'),
  (lemma: 'groß', kind: 'Adjektiv', example: 'eine große Wohnung'),
  (lemma: 'gut', kind: 'Adjektiv', example: 'ein gutes Buch'),
  (lemma: 'neu', kind: 'Adjektiv', example: 'ein neues Auto'),
  (lemma: 'freundlich', kind: 'Adjektiv', example: 'eine freundliche Frau'),
  (lemma: 'heute', kind: 'Adverb', example: 'Wir lernen heute.'),
  (lemma: 'gern', kind: 'Adverb', example: 'Ich lerne gern.'),
  (lemma: 'schnell', kind: 'Adverb', example: 'Er spricht schnell.'),
  (lemma: 'langsam', kind: 'Adverb', example: 'Sie spricht langsam.'),
  (lemma: 'hier', kind: 'Adverb', example: 'Wir wohnen hier.'),
];

const _prepositions = <({String lemma, List<String> examples})>[
  (
    lemma: 'in',
    examples: [
      'Wir wohnen in Berlin.',
      'Der Kurs ist in der Schule.',
      'Lara lebt in Deutschland.',
      'Die Kinder spielen in dem Garten.'
    ]
  ),
  (
    lemma: 'aus',
    examples: [
      'Ich komme aus Polen.',
      'Anna kommt aus Berlin.',
      'Das Brot kommt aus der Küche.',
      'Wir kommen aus der Schule.'
    ]
  ),
  (
    lemma: 'mit',
    examples: [
      'Sie lernt mit Anna.',
      'Wir spielen mit den Kindern.',
      'Er kommt mit dem Bus.',
      'Ich telefoniere mit der Familie.'
    ]
  ),
  (
    lemma: 'für',
    examples: [
      'Das Buch ist für Lara.',
      'Wir lernen für den Test.',
      'Ich koche für die Familie.',
      'Die Blumen sind für Anna.'
    ]
  ),
  (
    lemma: 'bei',
    examples: [
      'Er wohnt bei Ali.',
      'Ich bin bei der Familie.',
      'Lara arbeitet bei einer Firma.',
      'Das Kind bleibt bei der Mutter.'
    ]
  ),
];

void main() {
  final exercises = <Map<String, Object?>>[];
  var index = 1;
  for (final entry in _regular.entries) {
    for (final subject in _subjects) {
      for (final tail in entry.value.tails) {
        exercises.add({
          'id': 'regular-${index.toString().padLeft(4, '0')}',
          'topic_id': 'regular_present',
          'lemma': entry.key,
          'prompt': '${subject.text} ${entry.value.stem}_ $tail',
          'answer': subject.ending,
        });
        index++;
      }
    }
  }
  _addWholeFormExercises(
    exercises,
    topicId: 'sein',
    lemma: 'sein',
    forms: const ['bin', 'bist', 'ist', 'ist', 'sind', 'seid', 'sind', 'sind'],
    tails: _seinTails,
  );
  _addWholeFormExercises(
    exercises,
    topicId: 'haben',
    lemma: 'haben',
    forms: const [
      'habe',
      'hast',
      'hat',
      'hat',
      'haben',
      'habt',
      'haben',
      'haben'
    ],
    tails: _habenTails,
  );
  _addFoundationExercises(exercises);

  final regularCount = exercises
      .where((exercise) => exercise['topic_id'] == 'regular_present')
      .length;
  if (regularCount != 1000) {
    throw StateError('Expected 1000 regular exercises, got $regularCount.');
  }
  final ids = exercises.map((exercise) => exercise['id']).toSet();
  if (ids.length != exercises.length) throw StateError('Duplicate IDs.');

  final output = const JsonEncoder.withIndent('  ').convert({
    'version': 2,
    'exercises': exercises,
  });
  File('assets/grammar/exercises.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('$output\n');
}

void _addFoundationExercises(List<Map<String, Object?>> exercises) {
  for (final entry in _regular.entries) {
    final lemma = entry.key;
    final stem = entry.value.stem;
    _addExercise(
      exercises,
      id: 'verb-basics-$lemma',
      topicId: 'verb_basics',
      lemma: lemma,
      prompt: 'Welche Wortart ist „$lemma“?',
      answer: 'Verb',
      type: 'choice',
      options: const ['Nomen', 'Verb', 'Adjektiv'],
      instructionDe: 'Bestimme die Wortart.',
      instructionRu: 'Определите часть речи.',
    );
    _addExercise(
      exercises,
      id: 'stem-$lemma',
      topicId: 'infinitive_stem',
      lemma: lemma,
      prompt: 'Welche Form ist der Stamm von „$lemma“?',
      answer: stem,
      instructionDe: 'Schreibe nur den Stamm.',
      instructionRu: 'Напишите только основу.',
    );
    for (final subject in _subjects.take(3)) {
      _addExercise(
        exercises,
        id: 'pronoun-$lemma-${subject.key.replaceAll('/', '-')}',
        topicId: 'personal_pronouns',
        lemma: lemma,
        prompt: '___ $stem${subject.ending} Deutsch.',
        answer: subject.text,
        type: 'choice',
        options: [subject.text, 'Wir', 'Ihr'],
        instructionDe: 'Wähle das passende Personalpronomen.',
        instructionRu: 'Выберите подходящее личное местоимение.',
      );
    }
    _addExercise(
      exercises,
      id: 'part-verb-$lemma',
      topicId: 'parts_of_speech',
      lemma: lemma,
      prompt: '„$lemma“ bezeichnet eine Handlung. Welche Wortart ist das?',
      answer: 'Verb',
      type: 'choice',
      options: const ['Verb', 'Nomen', 'Präposition'],
      instructionDe: 'Ordne das markierte Wort zu.',
      instructionRu: 'Определите часть речи выделенного слова.',
    );

    final ichForm = '$stem${_subjects.first.ending}';
    final sentence = 'Ich $ichForm ${entry.value.tails.first}';
    _addExercise(
      exercises,
      id: 'order-$lemma-1',
      topicId: 'sentence_basics',
      lemma: lemma,
      prompt: 'Ordne die Wörter zu einem Aussagesatz.',
      answer: sentence,
      type: 'word_order',
      options: sentence.split(' ').reversed.toList(growable: false),
      instructionDe: 'Das konjugierte Verb steht an Position zwei.',
      instructionRu: 'Спрягаемый глагол должен стоять на втором месте.',
    );
    _addExercise(
      exercises,
      id: 'yes-no-$lemma-ja',
      topicId: 'yes_no_questions',
      lemma: lemma,
      prompt: 'Lara ${stem}t ${entry.value.tails.first} '
          '${_questionVerb(stem)} Lara ${entry.value.tails.first}',
      answer: 'Ja',
      type: 'yes_no',
      options: const ['Ja', 'Nein'],
      instructionDe: 'Stimmt die Frage mit der Information überein?',
      instructionRu: 'Совпадает ли вопрос с данной информацией?',
    );
    _addExercise(
      exercises,
      id: 'yes-no-$lemma-nein',
      topicId: 'yes_no_questions',
      lemma: lemma,
      prompt: 'Lara ${stem}t ${entry.value.tails.first} '
          '${_questionVerb(stem)} Anna ${entry.value.tails.first}',
      answer: 'Nein',
      type: 'yes_no',
      options: const ['Ja', 'Nein'],
      instructionDe: 'Stimmt die Frage mit der Information überein?',
      instructionRu: 'Совпадает ли вопрос с данной информацией?',
    );
  }

  const wQuestions = <({String lemma, String prompt, String answer})>[
    (lemma: 'wohnen', prompt: '___ wohnst du? – In Berlin.', answer: 'Wo'),
    (lemma: 'kommen', prompt: '___ kommst du? – Aus Polen.', answer: 'Woher'),
    (lemma: 'lernen', prompt: '___ lernst du? – Deutsch.', answer: 'Was'),
    (lemma: 'machen', prompt: '___ machst du das? – Langsam.', answer: 'Wie'),
    (lemma: 'fragen', prompt: '___ fragst du? – Den Lehrer.', answer: 'Wen'),
    (lemma: 'lernen', prompt: '___ lernst du? – Am Abend.', answer: 'Wann'),
    (lemma: 'lernen', prompt: '___ lernst du? – Zusammen.', answer: 'Wie'),
    (lemma: 'machen', prompt: '___ machst du? – Sport.', answer: 'Was'),
    (lemma: 'machen', prompt: '___ machst du Sport? – Heute.', answer: 'Wann'),
    (lemma: 'kommen', prompt: '___ kommst du? – Um acht.', answer: 'Wann'),
    (lemma: 'kommen', prompt: '___ kommst du? – Mit dem Bus.', answer: 'Wie'),
    (lemma: 'leben', prompt: '___ lebt Lara? – In Köln.', answer: 'Wo'),
    (lemma: 'leben', prompt: '___ lebt Lara? – Ruhig.', answer: 'Wie'),
    (lemma: 'kaufen', prompt: '___ kaufst du? – Brot.', answer: 'Was'),
    (
      lemma: 'kaufen',
      prompt: '___ kaufst du ein? – Am Samstag.',
      answer: 'Wann'
    ),
    (lemma: 'spielen', prompt: '___ spielt ihr? – Fußball.', answer: 'Was'),
    (lemma: 'spielen', prompt: '___ spielt ihr? – Im Garten.', answer: 'Wo'),
    (lemma: 'hören', prompt: '___ hörst du? – Musik.', answer: 'Was'),
    (lemma: 'kochen', prompt: '___ kocht ihr? – Am Abend.', answer: 'Wann'),
    (
      lemma: 'telefonieren',
      prompt: '___ telefonierst du? – Mit Anna.',
      answer: 'Mit wem'
    ),
  ];
  for (var index = 0; index < wQuestions.length; index++) {
    final question = wQuestions[index];
    _addExercise(
      exercises,
      id: 'w-question-${index + 1}',
      topicId: 'w_questions',
      lemma: question.lemma,
      prompt: question.prompt,
      answer: question.answer,
      type: 'choice',
      options: const [
        'Wer',
        'Was',
        'Wo',
        'Woher',
        'Wann',
        'Wie',
        'Wen',
        'Mit wem'
      ],
      instructionDe: 'Wähle das passende Fragewort.',
      instructionRu: 'Выберите подходящее вопросительное слово.',
    );
  }

  for (final noun in _nouns) {
    final lower = noun.lemma.toLowerCase();
    _addExercise(
      exercises,
      id: 'noun-capital-$lower',
      topicId: 'noun_basics',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Welche Schreibweise ist richtig?',
      answer: noun.lemma,
      type: 'choice',
      options: [lower, noun.lemma],
      instructionDe: 'Nomen beginnen mit einem Großbuchstaben.',
      instructionRu: 'Существительные начинаются с заглавной буквы.',
    );
    _addExercise(
      exercises,
      id: 'noun-capital-check-$lower',
      topicId: 'noun_basics',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Ist „$lower“ als Nomen richtig geschrieben?',
      answer: 'Nein',
      type: 'yes_no',
      options: const ['Ja', 'Nein'],
      instructionDe: 'Prüfe den ersten Buchstaben.',
      instructionRu: 'Проверьте первую букву.',
    );
    _addExercise(
      exercises,
      id: 'article-$lower',
      topicId: 'articles',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: '___ ${noun.lemma}',
      answer: noun.article,
      type: 'choice',
      options: const ['der', 'die', 'das'],
      instructionDe: 'Wähle den bestimmten Artikel.',
      instructionRu: 'Выберите определённый артикль.',
    );
    _addExercise(
      exercises,
      id: 'article-indefinite-$lower',
      topicId: 'articles',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Das ist ___ ${noun.lemma}.',
      answer: noun.article == 'die' ? 'eine' : 'ein',
      type: 'choice',
      options: const ['ein', 'eine'],
      instructionDe: 'Wähle den unbestimmten Artikel.',
      instructionRu: 'Выберите неопределённый артикль.',
    );
    _addExercise(
      exercises,
      id: 'part-noun-$lower',
      topicId: 'parts_of_speech',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Welche Wortart ist „${noun.lemma}“?',
      answer: 'Nomen',
      type: 'choice',
      options: const ['Verb', 'Nomen', 'Adjektiv'],
      instructionDe: 'Ordne das markierte Wort zu.',
      instructionRu: 'Определите часть речи выделенного слова.',
    );
    final accusativeArticle = noun.article == 'der' ? 'den' : noun.article;
    _addExercise(
      exercises,
      id: 'case-$lower-nominative',
      topicId: 'cases_intro',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: '${noun.article} ${noun.lemma} ist hier. Welche Rolle hat '
          '„${noun.article} ${noun.lemma}“?',
      answer: 'Nominativ',
      type: 'choice',
      options: const ['Nominativ', 'Akkusativ'],
      instructionDe: 'Wer oder was ist hier?',
      instructionRu: 'Кто или что находится здесь?',
    );
    _addExercise(
      exercises,
      id: 'case-$lower-accusative',
      topicId: 'cases_intro',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Ich sehe $accusativeArticle ${noun.lemma}. Welche Rolle hat '
          '„$accusativeArticle ${noun.lemma}“?',
      answer: 'Akkusativ',
      type: 'choice',
      options: const ['Nominativ', 'Akkusativ'],
      instructionDe: 'Wen oder was sehe ich?',
      instructionRu: 'Кого или что я вижу?',
    );
    _addExercise(
      exercises,
      id: 'negation-noun-$lower',
      topicId: 'negation',
      lemma: noun.lemma,
      itemType: 'noun',
      prompt: 'Ich habe ___ ${noun.lemma}.',
      answer: noun.article == 'die' ? 'keine' : 'kein',
      type: 'choice',
      options: const ['nicht', 'kein', 'keine'],
      instructionDe: 'Wähle die passende Negation.',
      instructionRu: 'Выберите подходящее отрицание.',
    );
  }

  for (final word in _describingWords) {
    _addExercise(
      exercises,
      id: 'description-${word.lemma}',
      topicId: 'adjectives_adverbs',
      lemma: word.lemma,
      itemType: 'word',
      prompt: '${word.example} – Welche Wortart hat „${word.lemma}“ hier?',
      answer: word.kind,
      type: 'choice',
      options: const ['Adjektiv', 'Adverb'],
      instructionDe: 'Achte darauf, was das Wort beschreibt.',
      instructionRu: 'Обратите внимание, что именно описывает слово.',
    );
    _addExercise(
      exercises,
      id: 'description-role-${word.lemma}',
      topicId: 'adjectives_adverbs',
      lemma: word.lemma,
      itemType: 'word',
      prompt: '${word.example} – Was beschreibt „${word.lemma}“?',
      answer: word.kind == 'Adjektiv' ? 'ein Nomen' : 'einen Umstand',
      type: 'choice',
      options: const ['ein Nomen', 'einen Umstand'],
      instructionDe: 'Unterscheide Eigenschaft und Umstand.',
      instructionRu: 'Отличите признак предмета от обстоятельства.',
    );
    _addExercise(
      exercises,
      id: 'part-word-${word.lemma}',
      topicId: 'parts_of_speech',
      lemma: word.lemma,
      itemType: 'word',
      prompt: 'Welche Wortart ist „${word.lemma}“ im Beispiel: '
          '${word.example}?',
      answer: word.kind,
      type: 'choice',
      options: const ['Verb', 'Nomen', 'Adjektiv', 'Adverb'],
      instructionDe: 'Ordne das markierte Wort zu.',
      instructionRu: 'Определите часть речи выделенного слова.',
    );
  }

  for (final preposition in _prepositions) {
    for (var index = 0; index < preposition.examples.length; index++) {
      _addExercise(
        exercises,
        id: 'preposition-${preposition.lemma}-${index + 1}',
        topicId: 'prepositions',
        lemma: preposition.lemma,
        itemType: 'word',
        prompt:
            preposition.examples[index].replaceFirst(preposition.lemma, '___'),
        answer: preposition.lemma,
        type: 'choice',
        options: _prepositions.map((item) => item.lemma).toList(),
        instructionDe: 'Wähle die Präposition mit der passenden Bedeutung.',
        instructionRu: 'Выберите предлог с подходящим значением.',
      );
    }
  }

  for (final entry in _regular.entries.take(10)) {
    _addExercise(
      exercises,
      id: 'negation-verb-${entry.key}',
      topicId: 'negation',
      lemma: entry.key,
      prompt: 'Ich ${entry.value.stem}e heute ___.',
      answer: 'nicht',
      type: 'choice',
      options: const ['nicht', 'kein', 'keine'],
      instructionDe: 'Hier wird die Handlung verneint.',
      instructionRu: 'Здесь отрицается действие.',
    );
  }
}

String _questionVerb(String stem) {
  final form = '${stem}t';
  return '${form[0].toUpperCase()}${form.substring(1)}';
}

void _addExercise(
  List<Map<String, Object?>> exercises, {
  required String id,
  required String topicId,
  required String lemma,
  required String prompt,
  required String answer,
  String itemType = 'verb',
  String type = 'text',
  List<String> options = const [],
  String instructionDe = '',
  String instructionRu = '',
}) {
  exercises.add({
    'id': id,
    'topic_id': topicId,
    'lemma': lemma.toLowerCase(),
    'required_item_type': itemType,
    'type': type,
    'prompt': prompt,
    'answer': answer,
    if (options.isNotEmpty) 'options': options,
    if (instructionDe.isNotEmpty) 'instruction_de': instructionDe,
    if (instructionRu.isNotEmpty) 'instruction_ru': instructionRu,
  });
}

void _addWholeFormExercises(
  List<Map<String, Object?>> exercises, {
  required String topicId,
  required String lemma,
  required List<String> forms,
  required List<String> tails,
}) {
  var index = 1;
  for (var subjectIndex = 0; subjectIndex < _subjects.length; subjectIndex++) {
    for (final tail in tails) {
      exercises.add({
        'id': '$topicId-${index.toString().padLeft(3, '0')}',
        'topic_id': topicId,
        'lemma': lemma,
        'prompt': '${_subjects[subjectIndex].text} ___ $tail',
        'answer': forms[subjectIndex],
      });
      index++;
    }
  }
}
