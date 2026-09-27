import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:deutsch_review/content/content_bundle.dart';
import 'package:deutsch_review/content/content_manifest.dart';
import 'package:deutsch_review/content/content_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes a valid bundle and rejects modified bytes', () async {
    final fixture = _fixture('2026.09.27.1');

    final decoded = await decodeContentBundle(fixture.manifest, fixture.bytes);

    expect(decoded.catalog.contentVersion, '2026.09.27.1');
    expect(decoded.catalog.topics.single.id, 'test-topic');
    final modified = Uint8List.fromList(fixture.bytes)..[10] ^= 1;
    await expectLater(
      decodeContentBundle(fixture.manifest, modified),
      throwsFormatException,
    );
  });

  test('installs atomically and keeps the previous active bundle on failure',
      () async {
    final directory = Directory.systemTemp.createTempSync('content_store_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = ContentStore(directory);
    final first = _fixture('2026.09.27.1');
    final second = _fixture('2026.09.27.2');

    await store.install(first.manifest, first.bytes);
    expect((await store.loadActive())?.manifest.contentVersion, '2026.09.27.1');

    final damaged = Uint8List.fromList(second.bytes)..[5] ^= 1;
    await expectLater(
      store.install(second.manifest, damaged),
      throwsFormatException,
    );
    expect((await store.loadActive())?.manifest.contentVersion, '2026.09.27.1');

    await store.install(second.manifest, second.bytes);
    expect((await store.loadVersion('2026.09.27.1'))?.catalog.contentVersion,
        '2026.09.27.1');
    expect((await store.loadActive())?.manifest.contentVersion, '2026.09.27.2');
  });

  test('removes only versions that are neither active nor retained', () async {
    final directory = Directory.systemTemp.createTempSync('content_cleanup_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final store = ContentStore(directory);
    final first = _fixture('2026.09.27.1');
    final second = _fixture('2026.09.27.2');
    final third = _fixture('2026.09.27.3');
    await store.install(first.manifest, first.bytes);
    await store.install(second.manifest, second.bytes);
    await store.install(third.manifest, third.bytes);

    await store.removeUnusedVersions({'2026.09.27.1'});

    expect(await store.loadVersion('2026.09.27.1'), isNotNull);
    expect(await store.loadVersion('2026.09.27.2'), isNull);
    expect((await store.loadActive())?.manifest.contentVersion, '2026.09.27.3');
  });
}

({ContentManifest manifest, Uint8List bytes}) _fixture(String version) {
  final catalog = <String, Object?>{
    'schema_version': 1,
    'content_version': version,
    'topics': <Object?>[
      <String, Object?>{
        'id': 'test-topic',
        'order': 1,
        'title_de': 'Test',
        'title_ru': 'Тест',
        'summary_de': 'Test',
        'summary_ru': 'Тест',
        'explanation_de': <String>['Test'],
        'explanation_ru': <String>['Тест'],
        'table': <Object?>[],
        'trainable': true,
      },
    ],
    'verbs': <Object?>[],
    'exercises': <Object?>[
      <String, Object?>{
        'id': 'test-exercise',
        'topic_id': 'test-topic',
        'lemma': '',
        'prompt': 'Ja?',
        'answer': 'Ja',
        'type': 'yes_no',
        'required_item_type': 'none',
        'options': <String>['Ja', 'Nein'],
      },
    ],
    'lesson_content': <String, Object?>{
      'alphabet': <Object?>[],
      'numbers': <Object?>[],
      'reading_rules': <Object?>[],
    },
  };
  final raw = utf8.encode(jsonEncode(catalog));
  final bytes = Uint8List.fromList(GZipCodec().encode(raw));
  return (
    manifest: ContentManifest(
      contentVersion: version,
      schemaVersion: 1,
      minimumAppContentSchema: 1,
      bundlePath: 'content/versions/$version/catalog.json.gz',
      sha256: sha256.convert(bytes).toString(),
      compressedSize: bytes.length,
      uncompressedSize: raw.length,
      publishedAt: DateTime.utc(2026, 9, 27),
    ),
    bytes: bytes,
  );
}
