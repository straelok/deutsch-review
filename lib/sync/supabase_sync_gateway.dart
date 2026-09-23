import 'package:supabase/supabase.dart';

import 'sync_gateway.dart';

final class SupabaseSyncGateway implements SyncGateway {
  SupabaseSyncGateway({required String url, required String publishableKey})
      : _client = SupabaseClient(url, publishableKey);

  final SupabaseClient _client;

  @override
  Future<Map<String, Object?>> synchronize({
    required String nickname,
    required Map<String, Object?> localPayload,
  }) async {
    final response = await _client.functions.invoke(
      'sync-profile',
      body: <String, Object?>{
        'nickname': nickname,
        'payload': localPayload,
      },
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Sync failed with HTTP ${response.status}.');
    }
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Sync response must be a JSON object.');
    }
    final payload = data['payload'];
    if (payload is! Map) {
      throw const FormatException('Sync response has no payload.');
    }
    return payload.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
  }
}
