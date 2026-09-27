import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import '../grammar/grammar_catalog.dart';
import 'content_manifest.dart';

final class ContentBundle {
  const ContentBundle({
    required this.manifest,
    required this.catalog,
    required this.compressedBytes,
  });

  final ContentManifest manifest;
  final GrammarCatalog catalog;
  final Uint8List compressedBytes;
}

Future<ContentBundle> loadBundledContent(AssetBundle assets) async {
  final manifestJson = _jsonObject(
    jsonDecode(await assets.loadString('assets/content/manifest.json')),
  );
  final manifest = ContentManifest.fromJson(manifestJson);
  final byteData = await assets.load('assets/content/catalog.json.gz');
  final bytes = byteData.buffer.asUint8List(
    byteData.offsetInBytes,
    byteData.lengthInBytes,
  );
  return decodeContentBundle(manifest, Uint8List.fromList(bytes));
}

Future<ContentBundle> decodeContentBundle(
  ContentManifest manifest,
  Uint8List compressedBytes,
) async {
  if (!manifest.isCompatible) {
    throw const FormatException('Content schema is not compatible.');
  }
  if (compressedBytes.length != manifest.compressedSize) {
    throw const FormatException('Compressed content size does not match.');
  }
  if (sha256.convert(compressedBytes).toString() != manifest.sha256) {
    throw const FormatException('Content hash does not match.');
  }
  final decoded = await Isolate.run(
    () => _decodeJson(compressedBytes, manifest.uncompressedSize),
  );
  if (decoded['schema_version'] != manifest.schemaVersion ||
      decoded['content_version'] != manifest.contentVersion) {
    throw const FormatException('Content identity does not match manifest.');
  }
  return ContentBundle(
    manifest: manifest,
    catalog: GrammarCatalog.fromPackageJson(decoded),
    compressedBytes: compressedBytes,
  );
}

Map<String, Object?> _decodeJson(Uint8List bytes, int expectedSize) {
  final raw = GZipCodec().decode(bytes);
  if (raw.length != expectedSize ||
      raw.length > ContentManifest.maximumUncompressedSize) {
    throw const FormatException('Uncompressed content size does not match.');
  }
  return _jsonObject(jsonDecode(utf8.decode(raw)));
}

Map<String, Object?> _jsonObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  return value.map(
    (key, item) => MapEntry(key.toString(), item as Object?),
  );
}
