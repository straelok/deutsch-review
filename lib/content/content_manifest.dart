final class ContentManifest {
  const ContentManifest({
    required this.contentVersion,
    required this.schemaVersion,
    required this.minimumAppContentSchema,
    required this.bundlePath,
    required this.sha256,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.publishedAt,
  });

  static const manifestVersion = 1;
  static const supportedSchemaVersion = 1;
  static const maximumCompressedSize = 1024 * 1024;
  static const maximumUncompressedSize = 5 * 1024 * 1024;

  final String contentVersion;
  final int schemaVersion;
  final int minimumAppContentSchema;
  final String bundlePath;
  final String sha256;
  final int compressedSize;
  final int uncompressedSize;
  final DateTime publishedAt;

  bool get isCompatible =>
      schemaVersion <= supportedSchemaVersion &&
      minimumAppContentSchema <= supportedSchemaVersion;

  factory ContentManifest.fromJson(Map<String, Object?> json) {
    if (_integer(json, 'manifest_version') != manifestVersion) {
      throw const FormatException('Unsupported content manifest version.');
    }
    final contentVersion = _string(json, 'content_version');
    if (!RegExp(r'^\d{4}\.\d{2}\.\d{2}\.\d+$').hasMatch(contentVersion)) {
      throw const FormatException('Invalid content version.');
    }
    final schemaVersion = _integer(json, 'schema_version');
    final minimumAppContentSchema = _integer(
      json,
      'minimum_app_content_schema',
    );
    final bundlePath = _string(json, 'bundle_path');
    if (bundlePath != 'content/versions/$contentVersion/catalog.json.gz') {
      throw const FormatException('Invalid content bundle path.');
    }
    final hash = _string(json, 'sha256');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid content hash.');
    }
    final compressedSize = _integer(json, 'compressed_size');
    final uncompressedSize = _integer(json, 'uncompressed_size');
    if (compressedSize <= 0 || compressedSize > maximumCompressedSize) {
      throw const FormatException('Invalid compressed content size.');
    }
    if (uncompressedSize <= 0 || uncompressedSize > maximumUncompressedSize) {
      throw const FormatException('Invalid uncompressed content size.');
    }
    final publishedAt = DateTime.tryParse(_string(json, 'published_at'));
    if (publishedAt == null) {
      throw const FormatException('Invalid content publication date.');
    }
    return ContentManifest(
      contentVersion: contentVersion,
      schemaVersion: schemaVersion,
      minimumAppContentSchema: minimumAppContentSchema,
      bundlePath: bundlePath,
      sha256: hash,
      compressedSize: compressedSize,
      uncompressedSize: uncompressedSize,
      publishedAt: publishedAt.toUtc(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'manifest_version': manifestVersion,
        'content_version': contentVersion,
        'schema_version': schemaVersion,
        'minimum_app_content_schema': minimumAppContentSchema,
        'bundle_path': bundlePath,
        'sha256': sha256,
        'compressed_size': compressedSize,
        'uncompressed_size': uncompressedSize,
        'published_at': publishedAt.toUtc().toIso8601String(),
      };

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static int _integer(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }
}
