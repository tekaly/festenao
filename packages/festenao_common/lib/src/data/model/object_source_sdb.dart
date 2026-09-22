import 'package:idb_shim/sdb.dart';

import 'object_edit_operation.dart';
import 'object_source.dart';
import 'object_source_sembast.dart';
import 'object_type_registry.dart';

/// The types an sdb record is edited with.
///
/// sdb reuses the sembast [SdbTimestamp] and [SdbBlob], so this is
/// [sembastObjectTypeRegistry] under the name the sdb side reads better with.
final sdbObjectTypeRegistry = sembastObjectTypeRegistry;

/// One sdb record.
class SdbObjectSource extends ObjectSource {
  /// The database the record lives in.
  final SdbDatabase database;

  /// The store the record lives in.
  final SdbStoreRef store;

  /// The primary key of the record.
  final Object key;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Source of the record [key] of [store].
  SdbObjectSource({
    required this.database,
    required this.store,
    required this.key,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? sdbObjectTypeRegistry;

  SdbRecordRef get _record => store.record(key);

  @override
  String get title => '${store.name}/$key';

  @override
  Future<Object?> read() => _record.getValue(database);

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    await _record.put(database, value as Object);
  }

  @override
  Stream<Object?> watch() =>
      _record.onSnapshot(database).map((snapshot) => snapshot?.value);

  @override
  Future<void> delete() {
    checkWritable('delete $title');
    return _record.delete(database);
  }
}

/// One sdb store.
///
/// The id of a record is its primary key as text. A store whose keys are ints
/// — the auto incremented ones — is handled: [listIds] remembers the keys it
/// listed, and an id that was not listed falls back to an int when it parses
/// as one.
class SdbObjectCollection extends ObjectCollection {
  /// The database the store lives in.
  final SdbDatabase database;

  /// The store.
  final SdbStoreRef store;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  final _keys = <String, Object>{};

  /// Collection of the records of [store].
  SdbObjectCollection({
    required this.database,
    required this.store,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? sdbObjectTypeRegistry;

  @override
  String get name => store.name;

  @override
  Future<List<String>> listIds({int? limit}) async {
    var snapshots = await store.findRecords(database, limit: limit);
    return snapshots.map(_rememberKey).toList();
  }

  @override
  Stream<List<String>> watchIds({int? limit}) => store
      .onSnapshots(database, options: SdbFindOptions(limit: limit))
      .map((snapshots) => snapshots.map(_rememberKey).toList());

  @override
  ObjectSource source(String id) => SdbObjectSource(
    database: database,
    store: store,
    key: _keys[id] ?? int.tryParse(id) ?? id,
    typeRegistry: typeRegistry,
    isReadOnly: isReadOnly,
  );

  @override
  Future<String> add(Object? value) async {
    checkWritable('add to $name');
    var key = await store.add(database, value as Object);
    var id = '$key';
    _keys[id] = key;
    return id;
  }

  String _rememberKey(SdbRecordSnapshot snapshot) {
    var key = snapshot.key;
    var id = '$key';
    _keys[id] = key;
    return id;
  }
}

/// One sdb database, the stores its schema declares.
class SdbObjectRepository extends ObjectRepository {
  /// The database.
  final SdbDatabase database;

  @override
  final String title;

  /// The types the records are edited with.
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Repository of the stores of [database].
  SdbObjectRepository(
    this.database, {
    String? title,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : title = title ?? database.name,
       typeRegistry = typeRegistry ?? sdbObjectTypeRegistry;

  @override
  Future<List<ObjectCollection>> listCollections() async => database.storeNames
      .map(
        (name) => SdbObjectCollection(
          database: database,
          store: SdbStoreRef<Object, Object>(name),
          typeRegistry: typeRegistry,
          isReadOnly: isReadOnly,
        ),
      )
      .toList();
}
