import 'package:bill_tracker/data/sync/conflict_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ConflictResolver resolver = ConflictResolver();
  final DateTime lastSync = DateTime.utc(2026, 1, 1);

  test('creates a remote record when no remote copy exists', () {
    expect(
      resolver.resolve(
        local: LocalSyncVersion(baseServerVersion: null, updatedAt: lastSync),
        remote: null,
      ),
      ConflictDecision.createRemote,
    );
  });

  test('surfaces concurrent edits for review', () {
    expect(
      resolver.resolve(
        local: LocalSyncVersion(
          baseServerVersion: 1,
          updatedAt: DateTime.utc(2026, 1, 3),
          lastSyncedAt: lastSync,
        ),
        remote: RemoteSyncVersion(
          serverVersion: 2,
          updatedAt: DateTime.utc(2026, 1, 2),
        ),
      ),
      ConflictDecision.needsReview,
    );
  });
}
