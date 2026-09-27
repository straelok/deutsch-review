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
  final serviceKey = Platform.environment['SUPABASE_SECRET_KEY'] ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (baseUrl == null ||
      baseUrl.isEmpty ||
      serviceKey == null ||
      serviceKey.isEmpty) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_SECRET_KEY '
      '(or SUPABASE_SERVICE_ROLE_KEY) are required.',
    );
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
    await _ensureBucket(client, baseUrl, serviceKey);
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

Future<void> _ensureBucket(
  HttpClient client,
  String baseUrl,
  String key,
) async {
  final getUri = Uri.parse('$baseUrl/storage/v1/bucket/learning-content');
  final getRequest = await client.getUrl(getUri);
  _authorize(getRequest, key);
  final getResponse = await getRequest.close();
  final getBody = await utf8.decoder.bind(getResponse).join();
  if (getResponse.statusCode >= 200 && getResponse.statusCode < 300) return;
  if (getResponse.statusCode != HttpStatus.notFound) {
    throw HttpException(
      'Bucket check failed (${getResponse.statusCode}): $getBody',
      uri: getUri,
    );
  }

  final createUri = Uri.parse('$baseUrl/storage/v1/bucket');
  final createRequest = await client.postUrl(createUri);
  _authorize(createRequest, key);
  createRequest.headers.contentType = ContentType.json;
  createRequest.write(jsonEncode({
    'id': 'learning-content',
    'name': 'learning-content',
    'public': true,
    'file_size_limit': 1048576,
    'allowed_mime_types': ['application/json', 'application/gzip'],
  }));
  final createResponse = await createRequest.close();
  final createBody = await utf8.decoder.bind(createResponse).join();
  if (createResponse.statusCode < 200 || createResponse.statusCode >= 300) {
    throw HttpException(
      'Bucket creation failed (${createResponse.statusCode}): $createBody',
      uri: createUri,
    );
  }
  stdout.writeln('Created public bucket learning-content.');
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
  _authorize(request, key);
  request.headers
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
  final uri =
      Uri.parse('$baseUrl/storage/v1/object/public/learning-content/$path');
  final request = await client.getUrl(uri);
  _authorize(request, key);
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

void _authorize(HttpClientRequest request, String key) {
  request.headers
    ..set(HttpHeaders.authorizationHeader, 'Bearer $key')
    ..set('apikey', key);
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
