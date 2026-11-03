import 'package:drift/drift.dart';

@DataClassName('SyncQueueRecord')
@TableIndex(name: 'sync_queue_created_idx', columns: <Symbol>{#queuedAt})
@TableIndex(
  name: 'sync_queue_entity_operation_idx',
  columns: <Symbol>{#entityType, #entityId, #operation},
  unique: true,
)
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text().withLength(min: 1, max: 64)();
  TextColumn get entityId => text()();
  TextColumn get operation => text().withLength(min: 1, max: 16)();
  TextColumn get payloadJson => text()();
  IntColumn get baseServerVersion => integer().nullable()();
  DateTimeColumn get queuedAt => dateTime()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
