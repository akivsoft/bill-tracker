/// Network boundary used by sync. Implementations must compare server
/// versions instead of overwriting a newer row with a blind upsert.
abstract interface class RemoteDataSource {
  Future<RemoteRecordSnapshot?> fetch(String table, String recordId);

  Future<RemoteWriteResult> writeIfVersionMatches({
    required String table,
    required String recordId,
    required Map<String, Object?> payload,
    required int? expectedServerVersion,
  });
}

class RemoteRecordSnapshot {
  const RemoteRecordSnapshot({
    required this.payload,
    required this.serverVersion,
    required this.updatedAt,
  });

  final Map<String, Object?> payload;
  final int serverVersion;
  final DateTime updatedAt;
}

sealed class RemoteWriteResult {
  const RemoteWriteResult();
}

final class RemoteWriteApplied extends RemoteWriteResult {
  const RemoteWriteApplied(this.snapshot);

  final RemoteRecordSnapshot snapshot;
}

final class RemoteWriteConflict extends RemoteWriteResult {
  const RemoteWriteConflict(this.currentSnapshot);

  final RemoteRecordSnapshot currentSnapshot;
}
