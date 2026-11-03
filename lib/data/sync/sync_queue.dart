import 'dart:convert';

import 'package:bill_tracker/data/local/database/app_database.dart';
import 'package:bill_tracker/data/local/database/tables/sync_queue.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

class SyncQueueStore {
  SyncQueueStore(this._database);

  final AppDatabase _database;
  static const Uuid _uuid = Uuid();

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
    int? baseServerVersion,
  }) async {
    final DateTime now = DateTime.now().toUtc();
    final SyncQueueRecord? existing =
        await (_database.select(_database.syncQueue)..where(
              (SyncQueue row) =>
                  row.entityType.equals(entityType) &
                  row.entityId.equals(entityId) &
                  row.operation.equals(operation),
            ))
            .getSingleOrNull();

    final Map<String, Object?> mergedPayload = existing == null
        ? payload
        : <String, Object?>{
            ...Map<String, Object?>.from(
              jsonDecode(existing.payloadJson) as Map,
            ),
            ...payload,
          };

    final SyncQueueCompanion update = SyncQueueCompanion(
      payloadJson: Value<String>(jsonEncode(mergedPayload)),
      queuedAt: Value<DateTime>(now),
      baseServerVersion: Value<int?>(baseServerVersion),
      attemptCount: const Value<int>(0),
      nextAttemptAt: const Value<DateTime?>(null),
      lastError: const Value<String?>(null),
    );

    if (existing == null) {
      await _database
          .into(_database.syncQueue)
          .insert(
            SyncQueueCompanion.insert(
              id: _uuid.v4(),
              entityType: entityType,
              entityId: entityId,
              operation: operation,
              payloadJson: jsonEncode(mergedPayload),
              baseServerVersion: Value<int?>(baseServerVersion),
              queuedAt: now,
            ),
          );
      return;
    }

    await (_database.update(
      _database.syncQueue,
    )..where((SyncQueue row) => row.id.equals(existing.id))).write(update);
  }

  Stream<List<SyncQueueRecord>> watchPending() =>
      (_database.select(_database.syncQueue)
            ..orderBy(<OrderingTerm Function(SyncQueue)>[
              (SyncQueue row) => OrderingTerm.asc(row.queuedAt),
            ]))
          .watch();
}
