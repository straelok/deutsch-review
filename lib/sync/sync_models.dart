enum SyncPhase {
  disconnected,
  idle,
  syncing,
  synced,
  error,
  unavailable,
}

String normalizeNickname(String value) => value.trim().toLowerCase();

bool isValidNickname(String value) {
  return RegExp(r'^[a-z0-9_-]{3,24}$').hasMatch(normalizeNickname(value));
}

final class SyncConfiguration {
  const SyncConfiguration({required this.url, required this.publishableKey});

  final String url;
  final String publishableKey;

  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static SyncConfiguration? fromEnvironment() {
    if (_url.isEmpty || _publishableKey.isEmpty) return null;
    return const SyncConfiguration(url: _url, publishableKey: _publishableKey);
  }
}
