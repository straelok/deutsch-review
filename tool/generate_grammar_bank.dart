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

  final regularCount = exercises
      .where((exercise) => exercise['topic_id'] == 'regular_present')
      .length;
  if (regularCount != 1000) {
    throw StateError('Expected 1000 regular exercises, got $regularCount.');
  }
  final ids = exercises.map((exercise) => exercise['id']).toSet();
  if (ids.length != exercises.length) throw StateError('Duplicate IDs.');

  final output = const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'exercises': exercises,
  });
  File('assets/grammar/exercises.json')
    ..createSync(recursive: true)
    ..writeAsStringSync('$output\n');
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
