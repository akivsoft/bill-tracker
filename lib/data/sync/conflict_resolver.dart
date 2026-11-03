enum ConflictDecision { createRemote, pushLocal, applyRemote, needsReview }

class LocalSyncVersion {
  const LocalSyncVersion({
    required this.baseServerVersion,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  final int? baseServerVersion;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;
}

class RemoteSyncVersion {
  const RemoteSyncVersion({
    required this.serverVersion,
    required this.updatedAt,
  });

  final int serverVersion;
  final DateTime updatedAt;
}

class ConflictResolver {
  const ConflictResolver();

  ConflictDecision resolve({
    required LocalSyncVersion local,
    required RemoteSyncVersion? remote,
  }) {
    if (remote == null) return ConflictDecision.createRemote;
    if (local.baseServerVersion == remote.serverVersion) {
      return ConflictDecision.pushLocal;
    }

    final DateTime? lastSyncedAt = local.lastSyncedAt;
    if (lastSyncedAt != null) {
      final bool localChanged = local.updatedAt.isAfter(lastSyncedAt);
      final bool remoteChanged = remote.updatedAt.isAfter(lastSyncedAt);
      if (!localChanged && remoteChanged) return ConflictDecision.applyRemote;
      if (localChanged && !remoteChanged) return ConflictDecision.pushLocal;
    }

    return ConflictDecision.needsReview;
  }
}
