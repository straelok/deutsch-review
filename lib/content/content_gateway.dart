import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'content_manifest.dart';

abstract interface class ContentGateway {
  Future<ContentManifest> fetchManifest();

  Future<ContentManifest> fetchVersionManifest(String version);

  Future<Uint8List> fetchBundle(ContentManifest manifest);
}

final class HttpContentGateway implements ContentGateway {
  HttpContentGateway({required String supabaseUrl, HttpClient? client})
      : _baseUrl = supabaseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? HttpClient();

  final String _baseUrl;
  final HttpClient _client;

  static const _bucket = 'learning-content';
  static const _manifestPath = 'content/latest/manifest.json';
  static const _maximumManifestSize = 32 * 1024;

  @override
  Future<ContentManifest> fetchManifest() async {
    return _fetchManifest(_manifestPath);
  }

  @override
  Future<ContentManifest> fetchVersionManifest(String version) {
    if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}\.\d+$').hasMatch(version)) {
      throw const FormatException('Invalid requested content version.');
    }
    return _fetchManifest('content/versions/$version/manifest.json');
  }

  Future<ContentManifest> _fetchManifest(String path) async {
    final bytes = await _get(path, _maximumManifestSize);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Content manifest must be an object.');
    }
    return ContentManifest.fromJson(
      decoded.map(
        (key, value) => MapEntry(key.toString(), value as Object?),
      ),
    );
  }

  @override
  Future<Uint8List> fetchBundle(ContentManifest manifest) {
    return _get(manifest.bundlePath, manifest.compressedSize);
  }

  Future<Uint8List> _get(String path, int maximumSize) async {
    final uri = Uri.parse(
      '$_baseUrl/storage/v1/object/public/$_bucket/$path',
    );
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException(
        'Content request failed with ${response.statusCode}.',
        uri: uri,
      );
    }
    if (response.contentLength > maximumSize) {
      await response.drain<void>();
      throw const FormatException('Remote content exceeds the size limit.');
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in response) {
      length += chunk.length;
      if (length > maximumSize) {
        throw const FormatException('Remote content exceeds the size limit.');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
