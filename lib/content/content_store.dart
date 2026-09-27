import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'content_bundle.dart';
import 'content_manifest.dart';

final class ContentStore {
  ContentStore(this.directory);

  final Directory directory;

  Directory get _versions => Directory(
        '${directory.path}${Platform.pathSeparator}versions',
      );
  File get _activeManifest => File(
        '${directory.path}${Platform.pathSeparator}active-manifest.json',
      );
  File get _previousManifest => File(
        '${directory.path}${Platform.pathSeparator}active-manifest.previous',
      );

  Future<ContentBundle?> loadActive() async {
    await _recoverManifest();
    if (!await _activeManifest.exists()) return null;
    try {
      final manifest = ContentManifest.fromJson(
        _jsonObject(jsonDecode(await _activeManifest.readAsString())),
      );
      final bundleFile = _bundleFile(manifest.contentVersion);
      if (!await bundleFile.exists()) return null;
      return await decodeContentBundle(
        manifest,
        Uint8List.fromList(await bundleFile.readAsBytes()),
      );
    } on Object {
      return null;
    }
  }

  Future<ContentBundle> install(
    ContentManifest manifest,
    Uint8List bytes,
  ) async {
    final verified = await decodeContentBundle(manifest, bytes);
    await _versions.create(recursive: true);
    final bundle = _bundleFile(manifest.contentVersion);
    if (!await bundle.exists()) {
      final temporary = File('${bundle.path}.temporary');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(bundle.path);
    }
    await _versionManifestFile(manifest.contentVersion).writeAsString(
      jsonEncode(manifest.toJson()),
      flush: true,
    );
    await _activate(manifest);
    return verified;
  }

  Future<ContentBundle?> loadVersion(String version) async {
    final active = await loadActive();
    if (active?.manifest.contentVersion == version) return active;
    final bundle = _bundleFile(version);
    final manifestFile = _versionManifestFile(version);
    if (!await bundle.exists() || !await manifestFile.exists()) return null;
    try {
      final manifest = ContentManifest.fromJson(
        _jsonObject(jsonDecode(await manifestFile.readAsString())),
      );
      return await decodeContentBundle(
        manifest,
        Uint8List.fromList(await bundle.readAsBytes()),
      );
    } on Object {
      return null;
    }
  }

  Future<void> removeUnusedVersions(Set<String> retainedVersions) async {
    final active = await loadActive();
    if (active != null) retainedVersions.add(active.manifest.contentVersion);
    if (!await _versions.exists()) return;
    await for (final entity in _versions.list()) {
      if (entity is! File) continue;
      if (entity.path.endsWith('.temporary')) {
        await entity.delete();
        continue;
      }
      if (!entity.path.endsWith('.json.gz')) continue;
      final name = entity.uri.pathSegments.last;
      final version = name.substring(0, name.length - '.json.gz'.length);
      if (!retainedVersions.contains(version)) {
        await entity.delete();
        final manifest = _versionManifestFile(version);
        if (await manifest.exists()) await manifest.delete();
      }
    }
  }

  File _bundleFile(String version) => File(
        '${_versions.path}${Platform.pathSeparator}$version.json.gz',
      );
  File _versionManifestFile(String version) => File(
        '${_versions.path}${Platform.pathSeparator}$version.manifest.json',
      );

  Future<void> _activate(ContentManifest manifest) async {
    await directory.create(recursive: true);
    final next = File('${_activeManifest.path}.next');
    await next.writeAsString(jsonEncode(manifest.toJson()), flush: true);
    if (await _previousManifest.exists()) await _previousManifest.delete();
    if (await _activeManifest.exists()) {
      await _activeManifest.rename(_previousManifest.path);
    }
    try {
      await next.rename(_activeManifest.path);
      if (await _previousManifest.exists()) await _previousManifest.delete();
    } catch (_) {
      if (!await _activeManifest.exists() && await _previousManifest.exists()) {
        await _previousManifest.rename(_activeManifest.path);
      }
      rethrow;
    }
  }

  Future<void> _recoverManifest() async {
    await directory.create(recursive: true);
    if (!await _activeManifest.exists() && await _previousManifest.exists()) {
      await _previousManifest.rename(_activeManifest.path);
    }
    final next = File('${_activeManifest.path}.next');
    if (await next.exists()) await next.delete();
  }

  static Map<String, Object?> _jsonObject(Object? value) {
    if (value is! Map) throw const FormatException('Expected a JSON object.');
    return value.map(
      (key, item) => MapEntry(key.toString(), item as Object?),
    );
  }
}
