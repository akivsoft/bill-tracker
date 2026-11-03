import 'package:drift/drift.dart';

@DataClassName('CategoryRecord')
@TableIndex(
  name: 'categories_user_type_name_idx',
  columns: <Symbol>{#userId, #categoryType, #name},
  unique: true,
)
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get categoryType => text().withLength(min: 1, max: 16)();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get localVersion => integer().withDefault(const Constant(1))();
  IntColumn get serverVersion => integer().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => <Column>{id};
}
