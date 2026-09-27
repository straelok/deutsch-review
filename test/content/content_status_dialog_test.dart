import 'dart:io';
import 'dart:typed_data';

import 'package:deutsch_review/content/content_bundle.dart';
import 'package:deutsch_review/content/content_controller.dart';
import 'package:deutsch_review/content/content_manifest.dart';
import 'package:deutsch_review/content/content_store.dart';
import 'package:deutsch_review/domain/app_language.dart';
import 'package:deutsch_review/features/content/content_status_dialog.dart';
import 'package:deutsch_review/grammar/grammar_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows content version, source and manual check action', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('content_dialog_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final bundle = await _fixture();
    final controller = ContentController(
      bundled: bundle,
      store: ContentStore(directory),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => showContentStatusDialog(
              context: context,
              controller: controller,
              language: AppLanguage.russian,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Учебные материалы'), findsOneWidget);
    expect(find.text('2026.09.27.1'), findsOneWidget);
    expect(find.text('Встроенная копия'), findsOneWidget);
    final check = tester.widget<FilledButton>(
      find.byKey(const Key('check-content-update')),
    );
    expect(check.onPressed, isNull);
  });
}

Future<ContentBundle> _fixture() async {
  const version = '2026.09.27.1';
  final manifest = ContentManifest(
    contentVersion: version,
    schemaVersion: 1,
    minimumAppContentSchema: 1,
    bundlePath: 'content/versions/$version/catalog.json.gz',
    sha256: List.filled(64, '0').join(),
    compressedSize: 1,
    uncompressedSize: 1,
    publishedAt: DateTime.utc(2026, 9, 27),
  );
  return ContentBundle(
    manifest: manifest,
    catalog: GrammarCatalog(
      contentVersion: version,
      topics: [],
      verbs: [],
      exercises: [],
    ),
    compressedBytes: Uint8List(1),
  );
}
