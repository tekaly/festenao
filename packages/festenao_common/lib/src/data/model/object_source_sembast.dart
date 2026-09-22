import 'dart:typed_data';

import 'package:sembast/blob.dart';
import 'package:sembast/timestamp.dart';
import 'package:sembast/utils/database_utils.dart';

import 'object_edit_operation.dart';
import 'object_source.dart';
import 'object_type.dart';
import 'object_type_registry.dart';

/// The sembast [Timestamp], encoded as an iso8601 string under `$timestamp`.
///
/// Same id and same encoding as the sembast V2 codec, so a record exported to
/// json reads back where it came from.
class SembastTimestampTypeHandler extends ObjectValueTypeHandler {
  /// Sembast timestamp handler.
  const SembastTimestampTypeHandler();

  @override
  String get id => 'timestamp';

  @override
  String get label => 'Timestamp';

  @override
  String get shortLabel => 'ts';

  /// A `dateTime` of a plain json document is the same iso8601 string.
  @override
  Set<String> get decodeAliases => const {'dateTime'};

  @override
  bool matches(Object? value) => value is Timestamp;

  @override
  Object? get newValue => Timestamp.now();

  @override
  String format(Object? value) => (value as Timestamp).toIso8601String();

  @override
  String toText(Object? value) => (value as Timestamp).toIso8601String();

  @override
  Object? parseText(String text) => Timestamp.parse(text.trim());

  @override
  Object? encode(Object? value) => (value as Timestamp).toIso8601String();

  @override
  Object? decode(Object? encoded) => Timestamp.parse(encoded as String);
}

/// The sembast [Blob], encoded as a base64 string under `$blob`.
class SembastBlobTypeHandler extends ObjectValueTypeHandler {
  /// Sembast blob handler.
  const SembastBlobTypeHandler();

  @override
  String get id => 'blob';

  @override
  String get label => 'Blob';

  @override
  String get shortLabel => 'byte';

  @override
  bool matches(Object? value) => value is Blob;

  @override
  Object? get newValue => Blob(Uint8List(0));

  @override
  String format(Object? value) {
    var length = (value as Blob).length;
    return '<$length ${length == 1 ? 'byte' : 'bytes'}>';
  }

  @override
  String toText(Object? value) => (value as Blob).toBase64();

  @override
  Object? parseText(String text) => Blob.fromBase64(text.trim());

  @override
  Object? encode(Object? value) => (value as Blob).toBase64();

  @override
  Object? decode(Object? encoded) => Blob.fromBase64(encoded as String);
}

/// The custom types a sembast (and an sdb) record may hold.
const sembastObjectTypeHandlers = <ObjectValueTypeHandler>[
  SembastTimestampTypeHandler(),
  SembastBlobTypeHandler(),
];

/// The types a sembast record is edited with: the basic ones plus the sembast
/// [Timestamp] and [Blob], which replace [objectTypeBytes].
final sembastObjectTypeRegistry = defaultObjectTypeRegistry.withHandlers(
  sembastObjectTypeHandlers,
);

/// One sembast record.
class SembastObjectSource extends ObjectSource {
  /// The database the record lives in.
  final Database database;

  /// The store the record lives in.
  final StoreRef store;

  /// The primary key of the record.
  final Object key;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Source of the record [key] of [store].
  SembastObjectSource({
    required this.database,
    required this.store,
    required this.key,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? sembastObjectTypeRegistry;

  RecordRef get _record => store.record(key);

  @override
  String get title => '${store.name}/$key';

  @override
  Future<Object?> read() => _record.get(database);

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    await _record.put(database, value);
  }

  @override
  Stream<Object?> watch() =>
      _record.onSnapshot(database).map((snapshot) => snapshot?.value);

  @override
  Future<void> delete() async {
    checkWritable('delete $title');
    await _record.delete(database);
  }
}

/// One sembast store.
///
/// The id of a record is its primary key as text. A store whose keys are ints
/// is handled: [listIds] remembers the keys it listed, and an id that was not
/// listed falls back to an int when it parses as one.
class SembastObjectCollection extends ObjectCollection {
  /// The database the store lives in.
  final Database database;

  /// The store.
  final StoreRef store;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  final _keys = <String, Object>{};

  /// Collection of the records of [store].
  SembastObjectCollection({
    required this.database,
    required this.store,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? sembastObjectTypeRegistry;

  @override
  String get name => store.name;

  @override
  Future<List<String>> listIds({int? limit}) async {
    var keys = await store.findKeys(database, finder: Finder(limit: limit));
    var ids = <String>[];
    for (var key in keys) {
      var id = '$key';
      _keys[id] = key as Object;
      ids.add(id);
    }
    return ids;
  }

  @override
  Stream<List<String>> watchIds({int? limit}) => store
      .query(finder: Finder(limit: limit))
      .onSnapshots(database)
      .map(
        (snapshots) => snapshots.map((snapshot) {
          var id = '${snapshot.key}';
          _keys[id] = snapshot.key as Object;
          return id;
        }).toList(),
      );

  @override
  ObjectSource source(String id) => SembastObjectSource(
    database: database,
    store: store,
    key: _keys[id] ?? int.tryParse(id) ?? id,
    typeRegistry: typeRegistry,
    isReadOnly: isReadOnly,
  );

  @override
  Future<String> add(Object? value) async {
    checkWritable('add to $name');
    var key = await store.add(database, value);
    var id = '$key';
    _keys[id] = key as Object;
    return id;
  }
}

/// One sembast database, its non empty stores.
class SembastObjectRepository extends ObjectRepository {
  /// The database.
  final Database database;

  @override
  final String title;

  /// The types the records are edited with.
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Repository of the stores of [database].
  SembastObjectRepository(
    this.database, {
    String? title,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : title = title ?? database.path,
       typeRegistry = typeRegistry ?? sembastObjectTypeRegistry;

  @override
  Future<List<ObjectCollection>> listCollections() async =>
      getNonEmptyStoreNames(database)
          .map(
            (name) => SembastObjectCollection(
              database: database,
              store: StoreRef<Object, Object>(name),
              typeRegistry: typeRegistry,
              isReadOnly: isReadOnly,
            ),
          )
          .toList();
}
