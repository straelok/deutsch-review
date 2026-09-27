import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:deutsch_review/content/content_bundle.dart';
import 'package:deutsch_review/content/content_controller.dart';
import 'package:deutsch_review/content/content_gateway.dart';
import 'package:deutsch_review/content/content_manifest.dart';
import 'package:deutsch_review/content/content_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks the manifest once per launch and skips unchanged bundle',
      () async {
    final directory = Directory.systemTemp.createTempSync('content_launch_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bundled = await _fixture('2026.09.27.1');
    final gateway = _FakeGateway(bundled);
    final controller = ContentController(
      bundled: bundled,
      store: ContentStore(directory),
      gateway: gateway,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkOnLaunch();
    await controller.checkOnLaunch();

    expect(gateway.manifestRequests, 1);
    expect(gateway.bundleRequests, 0);
    expect(controller.phase, ContentUpdatePhase.upToDate);
  });

  test('downloads and activates a valid newer catalog', () async {
    final directory = Directory.systemTemp.createTempSync('content_update_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bundled = await _fixture('2026.09.27.1');
    final update = await _fixture('2026.09.27.2');
    final gateway = _FakeGateway(update);
    final controller = ContentController(
      bundled: bundled,
      store: ContentStore(directory),
      gateway: gateway,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkOnLaunch();

    expect(gateway.manifestRequests, 1);
    expect(gateway.bundleRequests, 1);
    expect(controller.catalog.contentVersion, '2026.09.27.2');
    expect(controller.phase, ContentUpdatePhase.updated);
  });

  test('keeps active content when a downloaded update is invalid', () async {
    final directory = Directory.systemTemp.createTempSync('content_error_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bundled = await _fixture('2026.09.27.1');
    final update = await _fixture('2026.09.27.2');
    final gateway = _FakeGateway(
      ContentBundle(
        manifest: update.manifest,
        catalog: update.catalog,
        compressedBytes: Uint8List.fromList(update.compressedBytes)..[4] ^= 1,
      ),
    );
    final controller = ContentController(
      bundled: bundled,
      store: ContentStore(directory),
      gateway: gateway,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.checkOnLaunch();

    expect(controller.catalog.contentVersion, '2026.09.27.1');
    expect(controller.phase, ContentUpdatePhase.error);
  });
}

final class _FakeGateway implements ContentGateway {
  _FakeGateway(this.bundle);

  final ContentBundle bundle;
  int manifestRequests = 0;
  int bundleRequests = 0;

  @override
  Future<ContentManifest> fetchManifest() async {
    manifestRequests++;
    return bundle.manifest;
  }

  @override
  Future<Uint8List> fetchBundle(ContentManifest manifest) async {
    bundleRequests++;
    return bundle.compressedBytes;
  }
}

Future<ContentBundle> _fixture(String version) async {
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
  final manifest = ContentManifest(
    contentVersion: version,
    schemaVersion: 1,
    minimumAppContentSchema: 1,
    bundlePath: 'content/versions/$version/catalog.json.gz',
    sha256: sha256.convert(bytes).toString(),
    compressedSize: bytes.length,
    uncompressedSize: raw.length,
    publishedAt: DateTime.utc(2026, 9, 27, int.parse(version.split('.').last)),
  );
  return decodeContentBundle(manifest, bytes);
}
