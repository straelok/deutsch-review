import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<void> main(List<String> arguments) async {
  final options = _options(arguments);
  final input = Directory(options['input'] ?? 'assets/content');
  final manifestFile =
      File('${input.path}${Platform.pathSeparator}manifest.json');
  final bundleFile =
      File('${input.path}${Platform.pathSeparator}catalog.json.gz');
  final baseUrl =
      Platform.environment['SUPABASE_URL']?.replaceFirst(RegExp(r'/$'), '');
  final serviceKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (baseUrl == null ||
      baseUrl.isEmpty ||
      serviceKey == null ||
      serviceKey.isEmpty) {
    stderr.writeln('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required.');
    exitCode = 64;
    return;
  }
  final manifest = jsonDecode(await manifestFile.readAsString());
  if (manifest is! Map<String, Object?>) {
    throw const FormatException('manifest.json must be an object.');
  }
  final path = manifest['bundle_path'];
  final expectedHash = manifest['sha256'];
  if (path is! String || expectedHash is! String) {
    throw const FormatException('Manifest bundle path or hash is invalid.');
  }
  final bundle = await bundleFile.readAsBytes();
  if (sha256.convert(bundle).toString() != expectedHash) {
    throw StateError('Local bundle hash does not match manifest.');
  }

  final client = HttpClient();
  try {
    await _upload(
      client,
      baseUrl,
      serviceKey,
      path,
      bundle,
      contentType: 'application/gzip',
      upsert: false,
    );
    final downloaded = await _download(client, baseUrl, serviceKey, path);
    if (sha256.convert(downloaded).toString() != expectedHash) {
      throw StateError('Uploaded bundle verification failed.');
    }
    final version = manifest['content_version'];
    if (version is! String) {
      throw const FormatException('Manifest content version is invalid.');
    }
    await _upload(
      client,
      baseUrl,
      serviceKey,
      'content/versions/$version/manifest.json',
      await manifestFile.readAsBytes(),
      contentType: 'application/json',
      upsert: false,
    );
    await _upload(
      client,
      baseUrl,
      serviceKey,
      'content/latest/manifest.json',
      await manifestFile.readAsBytes(),
      contentType: 'application/json',
      upsert: true,
    );
  } finally {
    client.close(force: true);
  }
  stdout.writeln(
      'Published ${manifest['content_version']} and updated latest manifest.');
}

Future<void> _upload(
  HttpClient client,
  String baseUrl,
  String key,
  String path,
  List<int> bytes, {
  required String contentType,
  required bool upsert,
}) async {
  final uri = Uri.parse('$baseUrl/storage/v1/object/learning-content/$path');
  final request = await client.postUrl(uri);
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $key')
    ..set('apikey', key)
    ..set('x-upsert', upsert ? 'true' : 'false')
    ..contentType = ContentType.parse(contentType);
  request.add(bytes);
  final response = await request.close();
  final body = await utf8.decoder.bind(response).join();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException('Upload failed (${response.statusCode}): $body',
        uri: uri);
  }
}

Future<List<int>> _download(
  HttpClient client,
  String baseUrl,
  String key,
  String path,
) async {
  final uri = Uri.parse(
      '$baseUrl/storage/v1/object/authenticated/learning-content/$path');
  final request = await client.getUrl(uri);
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $key')
    ..set('apikey', key);
  final response = await request.close();
  final bytes = await response
      .fold<List<int>>(<int>[], (result, chunk) => result..addAll(chunk));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
        'Verification download failed (${response.statusCode}).',
        uri: uri);
  }
  return bytes;
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
