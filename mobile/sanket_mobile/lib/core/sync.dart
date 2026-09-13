abstract class SecureSessionStore {
  Future<void> save(String sessionId, Map<String, Object?> derivedData);
  Future<void> delete(String sessionId);
}

enum SyncState { queued, syncing, synced, failed }

class SyncOperation {
  const SyncOperation(this.sessionId, this.state, {this.error});
  final String sessionId;
  final SyncState state;
  final String? error;
}

abstract class DeferredSyncQueue {
  Future<void> enqueue(String sessionId);
  Future<List<SyncOperation>> retryPending();
}
