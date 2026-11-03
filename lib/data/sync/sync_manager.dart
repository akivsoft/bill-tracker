import 'package:bill_tracker/data/remote/remote_data_source.dart';
import 'package:bill_tracker/data/sync/conflict_resolver.dart';

class SyncManager {
  const SyncManager(this._remote, this._conflictResolver);

  final RemoteDataSource _remote;
  final ConflictResolver _conflictResolver;

  Future<ConflictDecision> inspect({
    required String table,
    required String recordId,
    required LocalSyncVersion localVersion,
  }) async {
    final RemoteRecordSnapshot? remote = await _remote.fetch(table, recordId);
    return _conflictResolver.resolve(
      local: localVersion,
      remote: remote == null
          ? null
          : RemoteSyncVersion(
              serverVersion: remote.serverVersion,
              updatedAt: remote.updatedAt,
            ),
    );
  }
}
