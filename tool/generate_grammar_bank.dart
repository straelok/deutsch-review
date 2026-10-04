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
  final curatedExercises = _loadCuratedExercises();
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
  _addLessonOneSpecialVerbExercises(exercises);
  _addLessonTwoExercises(exercises);
  _addLessonThreeFourExercises(exercises);
  _addFoundationExercises(exercises);
  final generatedIds = exercises.map((exercise) => exercise['id']).toSet();
  exercises.addAll(
    curatedExercises.where(
      (exercise) => generatedIds.add(exercise['id']),
    ),
  );

  final regularCount = exercises
      .where((exercise) => (exercise['id'] as String).startsWith('regular-'))
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

void _addLessonThreeFourExercises(List<Map<String, Object?>> exercises) {
  const moechtenItems = <({String lemma, String prompt, String answer})>[
    (lemma: 'möchten', prompt: 'Ich ___ einen Kaffee.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Du ___ Tee trinken.', answer: 'möchtest'),
    (lemma: 'möchten', prompt: 'Er ___ Brot kaufen.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Sie ___ eine Suppe.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Wir ___ bestellen.', answer: 'möchten'),
    (lemma: 'möchten', prompt: 'Ihr ___ zwei Brötchen.', answer: 'möchtet'),
    (lemma: 'möchten', prompt: 'Die Kinder ___ Saft.', answer: 'möchten'),
    (lemma: 'möchten', prompt: '___ Sie bezahlen?', answer: 'Möchten'),
    (lemma: 'möchten', prompt: 'Ich ___ ein Kilo Äpfel.', answer: 'möchte'),
    (lemma: 'möchten', prompt: '___ du etwas essen?', answer: 'Möchtest'),
    (lemma: 'möchten', prompt: 'Paul ___ Mineralwasser.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Anna ___ Gemüse kaufen.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Wir ___ eine Pizza.', answer: 'möchten'),
    (lemma: 'möchten', prompt: '___ ihr Kuchen?', answer: 'Möchtet'),
    (lemma: 'möchten', prompt: 'Meine Eltern ___ Kaffee.', answer: 'möchten'),
    (lemma: 'möchten', prompt: 'Was ___ Sie trinken?', answer: 'möchten'),
    (lemma: 'möchten', prompt: 'Ich ___ noch Milch.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Du ___ heute kochen.', answer: 'möchtest'),
    (lemma: 'möchten', prompt: 'Das Kind ___ ein Eis.', answer: 'möchte'),
    (lemma: 'möchten', prompt: 'Wir ___ die Rechnung.', answer: 'möchten'),
    (lemma: 'möchten', prompt: 'Ihr ___ Reis essen.', answer: 'möchtet'),
    (lemma: 'möchten', prompt: 'Die Kunden ___ bezahlen.', answer: 'möchten'),
    (
      lemma: 'möchten',
      prompt: '___ Sie ein Sonderangebot sehen?',
      answer: 'Möchten'
    ),
    (lemma: 'möchten', prompt: 'Wer ___ noch Tee?', answer: 'möchte'),
  ];
  for (var i = 0; i < moechtenItems.length; i++) {
    final item = moechtenItems[i];
    _addExercise(exercises,
        id: 'lesson3-moechten-${i + 1}',
        topicId: 'moechten',
        lemma: item.lemma,
        prompt: item.prompt,
        answer: item.answer,
        type: 'choice',
        options: const [
          'möchte',
          'möchtest',
          'möchten',
          'möchtet',
          'Möchte',
          'Möchten',
          'Möchtest'
        ],
        instructionDe: 'Wähle die passende Form von möchten.',
        instructionRu: 'Выберите подходящую форму глагола möchten.');
  }

  const pronounItems = <({String lemma, String prompt, String answer})>[
    (
      lemma: 'Balkon',
      prompt: 'Der Balkon ist klein. ___ ist aber schön.',
      answer: 'Er'
    ),
    (
      lemma: 'Tisch',
      prompt: 'Der Tisch ist neu. ___ kostet 80 Euro.',
      answer: 'Er'
    ),
    (
      lemma: 'Schrank',
      prompt: 'Der Schrank ist groß. ___ ist weiß.',
      answer: 'Er'
    ),
    (
      lemma: 'Teppich',
      prompt: 'Der Teppich ist alt. ___ ist billig.',
      answer: 'Er'
    ),
    (
      lemma: 'Fernseher',
      prompt: 'Der Fernseher ist hier. ___ ist neu.',
      answer: 'Er'
    ),
    (
      lemma: 'Flur',
      prompt: 'Der Flur ist schmal. ___ ist dunkel.',
      answer: 'Er'
    ),
    (lemma: 'Bad', prompt: 'Das Bad ist dort. ___ ist klein.', answer: 'Es'),
    (
      lemma: 'Zimmer',
      prompt: 'Das Zimmer ist hell. ___ ist schön.',
      answer: 'Es'
    ),
    (
      lemma: 'Sofa',
      prompt: 'Das Sofa ist modern. ___ kostet 300 Euro.',
      answer: 'Es'
    ),
    (
      lemma: 'Bett',
      prompt: 'Das Bett ist neu. ___ ist sehr breit.',
      answer: 'Es'
    ),
    (
      lemma: 'Regal',
      prompt: 'Das Regal ist hoch. ___ ist braun.',
      answer: 'Es'
    ),
    (
      lemma: 'Haus',
      prompt: 'Das Haus ist alt. ___ hat einen Garten.',
      answer: 'Es'
    ),
    (
      lemma: 'Küche',
      prompt: 'Die Küche ist neu. ___ ist sehr groß.',
      answer: 'Sie'
    ),
    (
      lemma: 'Wohnung',
      prompt: 'Die Wohnung ist teuer. ___ ist aber hell.',
      answer: 'Sie'
    ),
    (
      lemma: 'Lampe',
      prompt: 'Die Lampe ist gelb. ___ kostet 20 Euro.',
      answer: 'Sie'
    ),
    (
      lemma: 'Dusche',
      prompt: 'Die Dusche ist im Bad. ___ ist neu.',
      answer: 'Sie'
    ),
    (
      lemma: 'Garage',
      prompt: 'Die Garage ist klein. ___ ist neben dem Haus.',
      answer: 'Sie'
    ),
    (
      lemma: 'Miete',
      prompt: 'Die Miete ist hoch. ___ kostet 900 Euro.',
      answer: 'Sie'
    ),
    (
      lemma: 'Stuhl',
      prompt: 'Die Stühle sind alt. ___ sind billig.',
      answer: 'Sie'
    ),
    (
      lemma: 'Möbel',
      prompt: 'Die Möbel sind modern. ___ gefallen mir.',
      answer: 'Sie'
    ),
    (
      lemma: 'Zimmer',
      prompt: 'Die Zimmer sind hell. ___ sind groß.',
      answer: 'Sie'
    ),
    (
      lemma: 'Lampe',
      prompt: 'Die Lampen sind weiß. ___ sind schön.',
      answer: 'Sie'
    ),
    (
      lemma: 'Bett',
      prompt: 'Die Betten sind hier. ___ sind neu.',
      answer: 'Sie'
    ),
    (
      lemma: 'Sessel',
      prompt: 'Die Sessel sind bequem. ___ kosten 100 Euro.',
      answer: 'Sie'
    ),
  ];
  for (var i = 0; i < pronounItems.length; i++) {
    final item = pronounItems[i];
    _addExercise(exercises,
        id: 'lesson4-pronoun-${i + 1}',
        topicId: 'noun_pronouns',
        lemma: item.lemma,
        itemType: 'noun',
        prompt: item.prompt,
        answer: item.answer,
        type: 'choice',
        options: const ['Er', 'Es', 'Sie'],
        instructionDe: 'Ersetze das Nomen durch er, es oder sie.',
        instructionRu: 'Замените существительное на er, es или sie.');
  }

  const gefallenItems = <({String lemma, String prompt, String answer})>[
    (lemma: 'gefallen', prompt: 'Wie ___ dir der Tisch?', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Wie ___ Ihnen das Sofa?', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Mir ___ die Lampe.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Dir ___ der Teppich.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Uns ___ das Zimmer.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Wie ___ euch die Wohnung?', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Ihm ___ der Balkon.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Ihr ___ die Küche.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Wie ___ dir die Stühle?', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Wie ___ Ihnen die Möbel?', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Mir ___ die Betten.', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Dir ___ die Farben.', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Uns ___ die Zimmer.', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Wie ___ euch die Regale?', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Ihm ___ die Sessel.', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Ihr ___ die Lampen.', answer: 'gefallen'),
    (lemma: 'gefallen', prompt: 'Der Schrank ___ mir gut.', answer: 'gefällt'),
    (
      lemma: 'gefallen',
      prompt: 'Die Schränke ___ mir gut.',
      answer: 'gefallen'
    ),
    (lemma: 'gefallen', prompt: 'Das Bad ___ uns nicht.', answer: 'gefällt'),
    (lemma: 'gefallen', prompt: 'Die Sofas ___ uns sehr.', answer: 'gefallen'),
  ];
  for (var i = 0; i < gefallenItems.length; i++) {
    final item = gefallenItems[i];
    _addExercise(exercises,
        id: 'lesson4-gefallen-${i + 1}',
        topicId: 'gefallen',
        lemma: item.lemma,
        prompt: item.prompt,
        answer: item.answer,
        type: 'choice',
        options: const ['gefällt', 'gefallen'],
        instructionDe: 'Wähle gefällt oder gefallen.',
        instructionRu:
            'Выберите gefällt для одного предмета или gefallen для нескольких.');
  }
}

List<Map<String, Object?>> _loadCuratedExercises() {
  final file = File('assets/grammar/exercises.json');
  if (!file.existsSync()) return const [];

  final document = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final existing = document['exercises'] as List<Object?>? ?? const [];
  return existing.cast<Map<String, Object?>>().where((exercise) {
    final id = exercise['id'] as String? ?? '';
    return id.startsWith('reading-') || id.startsWith('verb-first-question-');
  }).toList(growable: false);
}

void _addLessonTwoExercises(List<Map<String, Object?>> exercises) {
  const possessives = <({
    String id,
    String lemma,
    String prompt,
    String answer,
    List<String> options,
  })>[
    (
      id: 'mein-01',
      lemma: 'Bruder',
      prompt: 'Das ist ___ Bruder.',
      answer: 'mein',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'mein-02',
      lemma: 'Kind',
      prompt: 'Das ist ___ Kind.',
      answer: 'mein',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'mein-03',
      lemma: 'Vater',
      prompt: 'Das ist ___ Vater.',
      answer: 'mein',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'mein-04',
      lemma: 'Sohn',
      prompt: 'Das ist ___ Sohn.',
      answer: 'mein',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'meine-01',
      lemma: 'Tochter',
      prompt: 'Das ist ___ Tochter.',
      answer: 'meine',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'meine-02',
      lemma: 'Mutter',
      prompt: 'Das ist ___ Mutter.',
      answer: 'meine',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'meine-03',
      lemma: 'Kind',
      prompt: 'Das sind ___ Kinder.',
      answer: 'meine',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'meine-04',
      lemma: 'Eltern',
      prompt: 'Das sind ___ Eltern.',
      answer: 'meine',
      options: ['mein', 'meine', 'meinen']
    ),
    (
      id: 'dein-01',
      lemma: 'Bruder',
      prompt: 'Ist das ___ Bruder?',
      answer: 'dein',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'dein-02',
      lemma: 'Kind',
      prompt: 'Ist das ___ Kind?',
      answer: 'dein',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'dein-03',
      lemma: 'Mann',
      prompt: 'Ist das ___ Mann?',
      answer: 'dein',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'dein-04',
      lemma: 'Opa',
      prompt: 'Ist das ___ Opa?',
      answer: 'dein',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'deine-01',
      lemma: 'Schwester',
      prompt: 'Ist das ___ Schwester?',
      answer: 'deine',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'deine-02',
      lemma: 'Oma',
      prompt: 'Ist das ___ Oma?',
      answer: 'deine',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'deine-03',
      lemma: 'Geschwister',
      prompt: 'Sind das ___ Geschwister?',
      answer: 'deine',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'deine-04',
      lemma: 'Großeltern',
      prompt: 'Sind das ___ Großeltern?',
      answer: 'deine',
      options: ['dein', 'deine', 'deinen']
    ),
    (
      id: 'ihr-01',
      lemma: 'Sohn',
      prompt: 'Frau Klein, ist das ___ Sohn?',
      answer: 'Ihr',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihr-02',
      lemma: 'Kind',
      prompt: 'Herr Rossi, ist das ___ Kind?',
      answer: 'Ihr',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihr-03',
      lemma: 'Mann',
      prompt: 'Frau Altmann, ist das ___ Mann?',
      answer: 'Ihr',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihr-04',
      lemma: 'Bruder',
      prompt: 'Frau Berg, ist das ___ Bruder?',
      answer: 'Ihr',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihre-01',
      lemma: 'Tochter',
      prompt: 'Herr Klein, ist das ___ Tochter?',
      answer: 'Ihre',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihre-02',
      lemma: 'Ehefrau',
      prompt: 'Herr Peters, ist das ___ Ehefrau?',
      answer: 'Ihre',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihre-03',
      lemma: 'Kind',
      prompt: 'Frau Glück, sind das ___ Kinder?',
      answer: 'Ihre',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
    (
      id: 'ihre-04',
      lemma: 'Eltern',
      prompt: 'Herr Bauer, sind das ___ Eltern?',
      answer: 'Ihre',
      options: ['Ihr', 'Ihre', 'Ihren']
    ),
  ];
  for (final item in possessives) {
    _addExercise(
      exercises,
      id: 'lesson2-possessive-${item.id}',
      topicId: 'possessive_articles',
      lemma: item.lemma,
      itemType: 'noun',
      prompt: item.prompt,
      answer: item.answer,
      type: 'choice',
      options: item.options,
      instructionDe: 'Wähle den passenden Possessivartikel im Nominativ.',
      instructionRu: 'Выберите подходящее притяжательное слово в Nominativ.',
    );
  }

  const addressItems =
      <({String id, String lemma, String prompt, String answer})>[
    (
      id: 'du-01',
      lemma: 'du',
      prompt: 'Tom, lernst ___ Deutsch?',
      answer: 'du'
    ),
    (id: 'du-02', lemma: 'du', prompt: 'Anna, wo wohnst ___?', answer: 'du'),
    (
      id: 'du-03',
      lemma: 'du',
      prompt: 'Peter, kommst ___ aus Wien?',
      answer: 'du'
    ),
    (
      id: 'ihr-01',
      lemma: 'ihr',
      prompt: 'Anna und Maria, lernt ___ Deutsch?',
      answer: 'ihr'
    ),
    (
      id: 'ihr-02',
      lemma: 'ihr',
      prompt: 'Mark und Robert, wo wohnt ___?',
      answer: 'ihr'
    ),
    (
      id: 'ihr-03',
      lemma: 'ihr',
      prompt: 'Kinder, kommt ___ aus Berlin?',
      answer: 'ihr'
    ),
    (
      id: 'sie-01',
      lemma: 'Sie',
      prompt: 'Frau Klein, wohnen ___ in München?',
      answer: 'Sie'
    ),
    (
      id: 'sie-02',
      lemma: 'Sie',
      prompt: 'Herr Berger, lernen ___ Deutsch?',
      answer: 'Sie'
    ),
    (
      id: 'sie-03',
      lemma: 'Sie',
      prompt: 'Herr und Frau Moor, haben ___ Zeit?',
      answer: 'Sie'
    ),
  ];
  for (final item in addressItems) {
    _addExercise(
      exercises,
      id: 'lesson2-address-${item.id}',
      topicId: 'regular_present',
      lemma: item.lemma,
      itemType: 'word',
      prompt: item.prompt,
      answer: item.answer,
      type: 'choice',
      options: const ['du', 'ihr', 'Sie'],
      instructionDe: 'Wähle die passende Anrede.',
      instructionRu: 'Выберите подходящую форму обращения.',
    );
  }

  const plurals = <({
    String id,
    String lemma,
    String prompt,
    String answer,
    List<String> options
  })>[
    (
      id: '01',
      lemma: 'Tisch',
      prompt: 'der Tisch — die ___',
      answer: 'Tische',
      options: ['Tische', 'Tischen', 'Tischs']
    ),
    (
      id: '02',
      lemma: 'Mann',
      prompt: 'der Mann — die ___',
      answer: 'Männer',
      options: ['Manne', 'Männer', 'Mannen']
    ),
    (
      id: '03',
      lemma: 'Apfel',
      prompt: 'der Apfel — die ___',
      answer: 'Äpfel',
      options: ['Apfeln', 'Apfels', 'Äpfel']
    ),
    (
      id: '04',
      lemma: 'Frau',
      prompt: 'die Frau — die ___',
      answer: 'Frauen',
      options: ['Fraue', 'Frauen', 'Fräuer']
    ),
    (
      id: '05',
      lemma: 'Schule',
      prompt: 'die Schule — die ___',
      answer: 'Schulen',
      options: ['Schule', 'Schulen', 'Schules']
    ),
    (
      id: '06',
      lemma: 'Lampe',
      prompt: 'die Lampe — die ___',
      answer: 'Lampen',
      options: ['Lampe', 'Lampen', 'Lampes']
    ),
    (
      id: '07',
      lemma: 'Haus',
      prompt: 'das Haus — die ___',
      answer: 'Häuser',
      options: ['Hausen', 'Hause', 'Häuser']
    ),
    (
      id: '08',
      lemma: 'Buch',
      prompt: 'das Buch — die ___',
      answer: 'Bücher',
      options: ['Buche', 'Bücher', 'Buchs']
    ),
    (
      id: '09',
      lemma: 'Kind',
      prompt: 'das Kind — die ___',
      answer: 'Kinder',
      options: ['Kinde', 'Kinder', 'Kinds']
    ),
    (
      id: '10',
      lemma: 'Auto',
      prompt: 'das Auto — die ___',
      answer: 'Autos',
      options: ['Auto', 'Autos', 'Auten']
    ),
    (
      id: '11',
      lemma: 'Brot',
      prompt: 'das Brot — die ___',
      answer: 'Brote',
      options: ['Brote', 'Broten', 'Brots']
    ),
    (
      id: '12',
      lemma: 'Wohnung',
      prompt: 'die Wohnung — die ___',
      answer: 'Wohnungen',
      options: ['Wohnunge', 'Wohnungen', 'Wohnungs']
    ),
  ];
  for (final item in plurals) {
    _addExercise(
      exercises,
      id: 'lesson2-plural-${item.id}',
      topicId: 'noun_basics',
      lemma: item.lemma,
      itemType: 'noun',
      prompt: item.prompt,
      answer: item.answer,
      type: 'choice',
      options: item.options,
      instructionDe: 'Wähle die richtige Pluralform.',
      instructionRu: 'Выберите правильную форму множественного числа.',
    );
  }

  const personalData = <({
    String id,
    String lemma,
    String prompt,
    String answer,
    List<String> options
  })>[
    (
      id: '01',
      lemma: 'Telefonnummer',
      prompt: 'Frage nach der Telefonnummer',
      answer: 'Wie ist Ihre Telefonnummer?',
      options: ['Wie', 'ist', 'Ihre', 'Telefonnummer?']
    ),
    (
      id: '02',
      lemma: 'Geburtsort',
      prompt: 'Frage nach dem Geburtsort',
      answer: 'Wo sind Sie geboren?',
      options: ['Wo', 'sind', 'Sie', 'geboren?']
    ),
    (
      id: '03',
      lemma: 'Wohnort',
      prompt: 'Frage nach dem Wohnort',
      answer: 'Wo wohnen Sie?',
      options: ['Wo', 'wohnen', 'Sie?']
    ),
    (
      id: '04',
      lemma: 'Adresse',
      prompt: 'Frage nach der Adresse',
      answer: 'Wie ist Ihre Adresse?',
      options: ['Wie', 'ist', 'Ihre', 'Adresse?']
    ),
    (
      id: '05',
      lemma: 'Familienstand',
      prompt: 'Frage nach dem Familienstand',
      answer: 'Sind Sie verheiratet?',
      options: ['Sind', 'Sie', 'verheiratet?']
    ),
    (
      id: '06',
      lemma: 'Kind',
      prompt: 'Frage nach Kindern',
      answer: 'Haben Sie Kinder?',
      options: ['Haben', 'Sie', 'Kinder?']
    ),
    (
      id: '07',
      lemma: 'Alter',
      prompt: 'Frage nach dem Alter eines Kindes',
      answer: 'Wie alt ist Ihr Kind?',
      options: ['Wie', 'alt', 'ist', 'Ihr', 'Kind?']
    ),
    (
      id: '08',
      lemma: 'Geburtsdatum',
      prompt: 'Frage nach dem Geburtsdatum',
      answer: 'Wie ist Ihr Geburtsdatum?',
      options: ['Wie', 'ist', 'Ihr', 'Geburtsdatum?']
    ),
  ];
  for (final item in personalData) {
    _addExercise(
      exercises,
      id: 'lesson2-personal-data-${item.id}',
      topicId: 'w_questions',
      lemma: item.lemma,
      itemType: 'noun',
      prompt: item.prompt,
      answer: item.answer,
      type: 'word_order',
      options: item.options,
      instructionDe: 'Bilde die passende Frage.',
      instructionRu: 'Составьте подходящий вопрос.',
    );
  }
}

void _addLessonOneSpecialVerbExercises(
  List<Map<String, Object?>> exercises,
) {
  const items = <({
    String id,
    String lemma,
    String prompt,
    String answer,
    List<String> options,
  })>[
    (
      id: 'heissen-01',
      lemma: 'heißen',
      prompt: 'Ich ___ Nora.',
      answer: 'heiße',
      options: ['heiße', 'heißt', 'heißen'],
    ),
    (
      id: 'heissen-02',
      lemma: 'heißen',
      prompt: 'Wie ___ du?',
      answer: 'heißt',
      options: ['heiße', 'heißt', 'heißen'],
    ),
    (
      id: 'heissen-03',
      lemma: 'heißen',
      prompt: 'Wie ___ Sie?',
      answer: 'heißen',
      options: ['heiße', 'heißt', 'heißen'],
    ),
    (
      id: 'heissen-04',
      lemma: 'heißen',
      prompt: 'Er ___ Amir.',
      answer: 'heißt',
      options: ['heiße', 'heißt', 'heißen'],
    ),
    (
      id: 'heissen-05',
      lemma: 'heißen',
      prompt: 'Wir ___ Berger.',
      answer: 'heißen',
      options: ['heiße', 'heißt', 'heißen'],
    ),
    (
      id: 'heissen-06',
      lemma: 'heißen',
      prompt: 'Ihr ___ Kaya.',
      answer: 'heißt',
      options: ['heißt', 'heißen', 'heiße'],
    ),
    (
      id: 'sprechen-01',
      lemma: 'sprechen',
      prompt: 'Ich ___ Deutsch.',
      answer: 'spreche',
      options: ['spreche', 'sprichst', 'sprechen'],
    ),
    (
      id: 'sprechen-02',
      lemma: 'sprechen',
      prompt: 'Was ___ du?',
      answer: 'sprichst',
      options: ['spreche', 'sprichst', 'sprechen'],
    ),
    (
      id: 'sprechen-03',
      lemma: 'sprechen',
      prompt: 'Was ___ Sie?',
      answer: 'sprechen',
      options: ['spreche', 'sprichst', 'sprechen'],
    ),
    (
      id: 'sprechen-04',
      lemma: 'sprechen',
      prompt: 'Sie ___ Polnisch.',
      answer: 'spricht',
      options: ['spricht', 'sprecht', 'sprechen'],
    ),
    (
      id: 'sprechen-05',
      lemma: 'sprechen',
      prompt: 'Wir ___ Arabisch.',
      answer: 'sprechen',
      options: ['spricht', 'sprecht', 'sprechen'],
    ),
    (
      id: 'sprechen-06',
      lemma: 'sprechen',
      prompt: 'Ihr ___ Englisch.',
      answer: 'sprecht',
      options: ['spricht', 'sprecht', 'sprechen'],
    ),
    (
      id: 'arbeiten-01',
      lemma: 'arbeiten',
      prompt: 'Ich ___ in Berlin.',
      answer: 'arbeite',
      options: ['arbeite', 'arbeitest', 'arbeitet'],
    ),
    (
      id: 'arbeiten-02',
      lemma: 'arbeiten',
      prompt: 'Wo ___ du?',
      answer: 'arbeitest',
      options: ['arbeite', 'arbeitest', 'arbeitet'],
    ),
    (
      id: 'arbeiten-03',
      lemma: 'arbeiten',
      prompt: 'Er ___ heute.',
      answer: 'arbeitet',
      options: ['arbeiten', 'arbeitest', 'arbeitet'],
    ),
    (
      id: 'arbeiten-04',
      lemma: 'arbeiten',
      prompt: 'Ihr ___ zusammen.',
      answer: 'arbeitet',
      options: ['arbeiten', 'arbeitet', 'arbeitest'],
    ),
    (
      id: 'reden-01',
      lemma: 'reden',
      prompt: 'Ich ___ mit Anna.',
      answer: 'rede',
      options: ['rede', 'redest', 'redet'],
    ),
    (
      id: 'reden-02',
      lemma: 'reden',
      prompt: 'Mit wem ___ du?',
      answer: 'redest',
      options: ['rede', 'redest', 'redet'],
    ),
    (
      id: 'reden-03',
      lemma: 'reden',
      prompt: 'Sie ___ über den Kurs.',
      answer: 'redet',
      options: ['reden', 'redest', 'redet'],
    ),
    (
      id: 'reden-04',
      lemma: 'reden',
      prompt: 'Ihr ___ leise.',
      answer: 'redet',
      options: ['reden', 'redet', 'redest'],
    ),
    (
      id: 'tanzen-01',
      lemma: 'tanzen',
      prompt: 'Ich ___ gern.',
      answer: 'tanze',
      options: ['tanze', 'tanzt', 'tanzen'],
    ),
    (
      id: 'tanzen-02',
      lemma: 'tanzen',
      prompt: 'Du ___ sehr gut.',
      answer: 'tanzt',
      options: ['tanze', 'tanzt', 'tanzen'],
    ),
    (
      id: 'tanzen-03',
      lemma: 'tanzen',
      prompt: 'Er ___ heute.',
      answer: 'tanzt',
      options: ['tanze', 'tanzt', 'tanzen'],
    ),
    (
      id: 'tanzen-04',
      lemma: 'tanzen',
      prompt: 'Wir ___ zusammen.',
      answer: 'tanzen',
      options: ['tanze', 'tanzt', 'tanzen'],
    ),
  ];
  for (final item in items) {
    _addExercise(
      exercises,
      id: 'lesson1-special-${item.id}',
      topicId: 'lesson1_special_verbs',
      lemma: item.lemma,
      prompt: item.prompt,
      answer: item.answer,
      type: 'choice',
      options: item.options,
      instructionDe: 'Wähle die richtige Verbform.',
      instructionRu: 'Выберите правильную форму глагола.',
    );
  }

  const questions = <({
    String id,
    String lemma,
    String prompt,
    String answer,
    List<String> options,
  })>[
    (
      id: 'frage-01',
      lemma: 'heißen',
      prompt: 'Frage mit du: Name',
      answer: 'Wie heißt du?',
      options: ['Wie', 'heißt', 'du?'],
    ),
    (
      id: 'frage-02',
      lemma: 'heißen',
      prompt: 'Höfliche Frage: Name',
      answer: 'Wie heißen Sie?',
      options: ['Wie', 'heißen', 'Sie?'],
    ),
    (
      id: 'frage-03',
      lemma: 'sprechen',
      prompt: 'Frage mit du: Sprache',
      answer: 'Was sprichst du?',
      options: ['Was', 'sprichst', 'du?'],
    ),
    (
      id: 'frage-04',
      lemma: 'sprechen',
      prompt: 'Höfliche Frage: Sprache',
      answer: 'Was sprechen Sie?',
      options: ['Was', 'sprechen', 'Sie?'],
    ),
  ];
  for (final item in questions) {
    _addExercise(
      exercises,
      id: 'lesson1-special-${item.id}',
      topicId: 'lesson1_special_verbs',
      lemma: item.lemma,
      prompt: item.prompt,
      answer: item.answer,
      type: 'word_order',
      options: item.options,
      instructionDe: 'Bilde eine W-Frage.',
      instructionRu: 'Составьте вопрос с вопросительным словом.',
    );
  }

  const dochItems = <({String id, String prompt, String answer})>[
    (id: 'doch-01', prompt: 'Lernst du nicht Deutsch? — ___!', answer: 'Doch'),
    (id: 'doch-02', prompt: 'Arbeitet er heute nicht? — ___!', answer: 'Doch'),
    (
      id: 'doch-03',
      prompt: 'Kommen Sie nicht aus Berlin? — ___!',
      answer: 'Doch'
    ),
    (
      id: 'doch-04',
      prompt: 'Sprichst du kein Englisch? — ___!',
      answer: 'Doch'
    ),
  ];
  for (final item in dochItems) {
    _addExercise(
      exercises,
      id: 'lesson1-special-${item.id}',
      topicId: 'yes_no_questions',
      lemma: 'doch',
      itemType: 'word',
      prompt: item.prompt,
      answer: item.answer,
      type: 'choice',
      options: const ['Doch', 'Nein', 'Ja'],
      instructionDe: 'Wähle die passende Antwort auf die negative Frage.',
      instructionRu: 'Выберите подходящий ответ на отрицательный вопрос.',
    );
  }
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
        topicId: 'regular_present',
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
