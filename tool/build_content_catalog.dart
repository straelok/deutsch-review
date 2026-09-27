import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const _maximumCompressedSize = 1024 * 1024;
const _maximumUncompressedSize = 5 * 1024 * 1024;
const _contentVersionPattern = r'^\d{4}\.\d{2}\.\d{2}\.\d+$';

void main(List<String> arguments) {
  final options = _options(arguments);
  final version = options['version'];
  if (version == null || !RegExp(_contentVersionPattern).hasMatch(version)) {
    stderr.writeln(
      'Usage: dart run tool/build_content_catalog.dart '
      '--version=YYYY.MM.DD.N [--output=assets/content]',
    );
    exitCode = 64;
    return;
  }

  final outputDirectory = Directory(options['output'] ?? 'assets/content')
    ..createSync(recursive: true);
  final topicsSource = _object(
    jsonDecode(File('assets/grammar/topics.json').readAsStringSync()),
    'topics.json',
  );
  final exercisesSource = _object(
    jsonDecode(File('assets/grammar/exercises.json').readAsStringSync()),
    'exercises.json',
  );
  final topics = _objects(topicsSource['topics'], 'topics');
  final verbs = _objects(topicsSource['verbs'], 'verbs');
  final exercises = _objects(exercisesSource['exercises'], 'exercises');

  _validate(topics: topics, verbs: verbs, exercises: exercises);

  final catalog = <String, Object?>{
    'schema_version': 1,
    'content_version': version,
    'topics': topics,
    'verbs': verbs,
    'exercises': exercises,
    'lesson_content': <String, Object?>{
      'alphabet': const <Object?>[],
      'numbers': const <Object?>[],
      'reading_rules': const <Object?>[],
    },
  };
  final rawBytes = utf8.encode(jsonEncode(catalog));
  if (rawBytes.length > _maximumUncompressedSize) {
    throw StateError('Catalog exceeds $_maximumUncompressedSize bytes.');
  }
  final compressedBytes = GZipCodec(level: 9).encode(rawBytes);
  if (compressedBytes.length > _maximumCompressedSize) {
    throw StateError(
        'Compressed catalog exceeds $_maximumCompressedSize bytes.');
  }

  final bundleName = 'catalog.json.gz';
  File('${outputDirectory.path}${Platform.pathSeparator}$bundleName')
      .writeAsBytesSync(compressedBytes, flush: true);
  final publishedAt =
      options['published-at'] ?? DateTime.now().toUtc().toIso8601String();
  if (DateTime.tryParse(publishedAt) == null) {
    throw const FormatException('published-at must be an ISO-8601 date.');
  }
  final manifest = <String, Object?>{
    'manifest_version': 1,
    'content_version': version,
    'schema_version': 1,
    'minimum_app_content_schema': 1,
    'bundle_path': 'content/versions/$version/$bundleName',
    'sha256': sha256.convert(compressedBytes).toString(),
    'compressed_size': compressedBytes.length,
    'uncompressed_size': rawBytes.length,
    'published_at': DateTime.parse(publishedAt).toUtc().toIso8601String(),
  };
  File('${outputDirectory.path}${Platform.pathSeparator}manifest.json')
      .writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    flush: true,
  );

  stdout.writeln(
    'Built content $version: ${exercises.length} exercises, '
    '${compressedBytes.length} compressed bytes, '
    '${rawBytes.length} uncompressed bytes.',
  );
}

Map<String, String> _options(List<String> arguments) {
  final result = <String, String>{};
  for (final argument in arguments) {
    if (!argument.startsWith('--') || !argument.contains('=')) continue;
    final separator = argument.indexOf('=');
    result[argument.substring(2, separator)] =
        argument.substring(separator + 1);
  }
  return result;
}

void _validate({
  required List<Map<String, Object?>> topics,
  required List<Map<String, Object?>> verbs,
  required List<Map<String, Object?>> exercises,
}) {
  final topicIds = _uniqueStrings(topics, 'id', 'topic');
  _uniqueStrings(exercises, 'id', 'exercise');
  final lemmas = <String>{};
  for (final verb in verbs) {
    final lemma = _requiredString(verb, 'lemma').trim().toLowerCase();
    if (!lemmas.add(lemma)) {
      throw FormatException('Duplicate verb lemma: $lemma');
    }
    final topicId = _requiredString(verb, 'topic_id');
    if (!topicIds.contains(topicId)) {
      throw FormatException('Verb $lemma references unknown topic $topicId.');
    }
    if (verb['forms'] is! Map) {
      throw FormatException('Verb $lemma must contain forms.');
    }
  }
  const types = {'text', 'choice', 'yes_no', 'word_order'};
  for (final exercise in exercises) {
    final id = _requiredString(exercise, 'id');
    final topicId = _requiredString(exercise, 'topic_id');
    if (!topicIds.contains(topicId)) {
      throw FormatException('Exercise $id references unknown topic $topicId.');
    }
    _requiredString(exercise, 'prompt');
    _requiredString(exercise, 'answer');
    final type = exercise['type'] ?? 'text';
    if (type is! String || !types.contains(type)) {
      throw FormatException('Exercise $id has unsupported type $type.');
    }
    if ((type == 'choice' || type == 'yes_no' || type == 'word_order') &&
        exercise['options'] is! List) {
      throw FormatException('Exercise $id requires options.');
    }
  }
}

Set<String> _uniqueStrings(
  List<Map<String, Object?>> entries,
  String field,
  String label,
) {
  final values = <String>{};
  for (final entry in entries) {
    final value = _requiredString(entry, field);
    if (!values.add(value)) {
      throw FormatException('Duplicate $label $field: $value');
    }
  }
  return values;
}

String _requiredString(Map<String, Object?> value, String key) {
  final field = value[key];
  if (field is! String || field.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return field;
}

Map<String, Object?> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, item) => MapEntry(key.toString(), item as Object?));
}

List<Map<String, Object?>> _objects(Object? value, String label) {
  if (value is! List) throw FormatException('$label must be an array.');
  return value
      .map((entry) => _object(entry, '$label entry'))
      .toList(growable: false);
}
