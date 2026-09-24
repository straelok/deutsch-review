import 'dart:convert';

import '../domain/id_generator.dart';
import '../domain/learning_item.dart';

final class WordJsonCodec {
  const WordJsonCodec();

  static const formatVersion = 1;

  String encode(List<LearningItem> items, {required DateTime exportedAt}) {
    final package = <String, Object?>{
      'format_version': formatVersion,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'words': items.map(_encodeItem).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(package);
  }

  List<LearningItem> decode(String source, {required DateTime importedAt}) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Корень JSON должен быть объектом.');
    }
    if (decoded['format_version'] != formatVersion) {
      throw const FormatException('Поддерживается только format_version 1.');
    }
    final words = decoded['words'];
    if (words is! List) {
      throw const FormatException('Поле words должно быть массивом.');
    }
    return <LearningItem>[
      for (var index = 0; index < words.length; index++)
        _decodeItem(words[index], index, importedAt.toUtc()),
    ];
  }

  static Map<String, Object?> _encodeItem(LearningItem item) {
    final content = item.content;
    return <String, Object?>{
      'id': item.id,
      'type': item.type.wireName,
      'german': content['german'],
      'translation_ru': content['translation_ru'],
      if (item.type == LearningItemType.noun) 'article': content['article'],
      if (item.type == LearningItemType.noun) 'plural': content['plural'],
      if (content['example'] case final String value) 'example': value,
      if (content['note'] case final String value) 'note': value,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'updated_at': item.updatedAt.toUtc().toIso8601String(),
    };
  }

  static LearningItem _decodeItem(Object? value, int index, DateTime now) {
    if (value is! Map<String, Object?>) {
      throw FormatException('words[$index] должен быть объектом.');
    }
    final typeName = _requiredString(value, 'type', index);
    final type = switch (typeName) {
      'word' => LearningItemType.word,
      'noun' => LearningItemType.noun,
      _ => throw FormatException(
          'words[$index].type должен быть word или noun.',
        ),
    };
    final german = _requiredString(value, 'german', index);
    final translation = _requiredString(value, 'translation_ru', index);
    final article = type == LearningItemType.noun
        ? _requiredString(value, 'article', index)
        : null;
    if (article != null && !const {'der', 'die', 'das'}.contains(article)) {
      throw FormatException(
          'words[$index].article должен быть der, die или das.');
    }
    final plural = type == LearningItemType.noun
        ? _requiredString(value, 'plural', index)
        : null;
    final id = _optionalString(value['id']) ?? newUuidV4();
    final createdAt =
        _optionalDate(value['created_at'], index, 'created_at') ?? now;
    final updatedAt =
        _optionalDate(value['updated_at'], index, 'updated_at') ?? now;

    return LearningItem(
      id: id,
      type: type,
      level: '',
      lesson: '',
      topic: '',
      learned: true,
      createdAt: createdAt,
      updatedAt: updatedAt.isBefore(createdAt) ? createdAt : updatedAt,
      sourceRef: 'json',
      content: <String, Object?>{
        'german': german,
        'translation_ru': translation,
        if (article != null) 'article': article,
        if (plural != null) 'plural': plural,
        if (_optionalString(value['example']) case final value?)
          'example': value,
        if (_optionalString(value['note']) case final value?) 'note': value,
      },
    );
  }

  static String _requiredString(
    Map<String, Object?> value,
    String field,
    int index,
  ) {
    final result = _optionalString(value[field]);
    if (result == null) {
      throw FormatException('words[$index].$field обязательно.');
    }
    return result;
  }

  static String? _optionalString(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static DateTime? _optionalDate(Object? value, int index, String field) {
    final text = _optionalString(value);
    if (text == null) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed == null) {
      throw FormatException('words[$index].$field содержит неверную дату.');
    }
    return parsed.toUtc();
  }
}
