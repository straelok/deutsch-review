abstract interface class SyncGateway {
  Future<Map<String, Object?>> synchronize({
    required String nickname,
    required Map<String, Object?> localPayload,
  });
}
