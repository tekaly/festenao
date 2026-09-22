import 'dart:typed_data';

import 'package:tekartik_firebase_firestore/firestore.dart';

import 'object_edit_operation.dart';
import 'object_source.dart';
import 'object_type.dart';
import 'object_type_registry.dart';

/// The firestore [Timestamp], encoded as an iso8601 string under `$timestamp`.
class FirestoreTimestampTypeHandler extends ObjectValueTypeHandler {
  /// Firestore timestamp handler.
  const FirestoreTimestampTypeHandler();

  @override
  String get id => 'timestamp';

  @override
  String get label => 'Timestamp';

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

/// The firestore [Blob], encoded as a base64 string under `$blob`.
class FirestoreBlobTypeHandler extends ObjectValueTypeHandler {
  /// Firestore blob handler.
  const FirestoreBlobTypeHandler();

  @override
  String get id => 'blob';

  @override
  String get label => 'Blob';

  @override
  bool matches(Object? value) => value is Blob;

  @override
  Object? get newValue => Blob(Uint8List(0));

  @override
  String format(Object? value) {
    var length = (value as Blob).bytes.length;
    return '<$length ${length == 1 ? 'byte' : 'bytes'}>';
  }

  @override
  String toText(Object? value) => '${value as Blob}';

  @override
  Object? parseText(String text) =>
      Blob(objectTypeBytes.parseText(text) as Uint8List);

  @override
  Object? encode(Object? value) => '${value as Blob}';

  @override
  Object? decode(Object? encoded) =>
      Blob(objectTypeBytes.parseText(encoded as String) as Uint8List);
}

/// The firestore [GeoPoint], edited as `latitude,longitude` and encoded as a
/// two field map under `$geoPoint`.
class FirestoreGeoPointTypeHandler extends ObjectValueTypeHandler {
  /// Firestore geo point handler.
  const FirestoreGeoPointTypeHandler();

  @override
  String get id => 'geoPoint';

  @override
  String get label => 'GeoPoint';

  @override
  bool matches(Object? value) => value is GeoPoint;

  @override
  Object? get newValue => const GeoPoint(0, 0);

  @override
  String format(Object? value) => toText(value);

  @override
  String toText(Object? value) {
    var point = value as GeoPoint;
    return '${point.latitude},${point.longitude}';
  }

  @override
  Object? parseText(String text) {
    var parts = text.split(',');
    if (parts.length != 2) {
      throw FormatException('Not a latitude,longitude pair', text);
    }
    var latitude = num.tryParse(parts[0].trim());
    var longitude = num.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) {
      throw FormatException('Not a latitude,longitude pair', text);
    }
    return GeoPoint(latitude, longitude);
  }

  @override
  Object? encode(Object? value) {
    var point = value as GeoPoint;
    return <String, Object?>{
      'latitude': point.latitude,
      'longitude': point.longitude,
    };
  }

  @override
  Object? decode(Object? encoded) {
    var map = encoded as Map;
    return GeoPoint(map['latitude'] as num, map['longitude'] as num);
  }
}

/// A firestore [DocumentReference], edited as its path and encoded as that
/// path under `$documentReference`.
///
/// It needs the [Firestore] a path is resolved against, so unlike the other
/// handlers it is not a constant, see [firestoreObjectTypeRegistry].
class FirestoreDocumentReferenceTypeHandler extends ObjectValueTypeHandler {
  /// The instance a path is resolved against.
  final Firestore firestore;

  /// Document reference handler of [firestore].
  const FirestoreDocumentReferenceTypeHandler(this.firestore);

  @override
  String get id => 'documentReference';

  @override
  String get label => 'Reference';

  @override
  bool matches(Object? value) => value is DocumentReference;

  @override
  Object? get newValue => null;

  @override
  String format(Object? value) => (value as DocumentReference).path;

  @override
  String toText(Object? value) => (value as DocumentReference).path;

  @override
  Object? parseText(String text) {
    var path = text.trim();
    if (path.isEmpty) {
      throw FormatException('Not a document path', text);
    }
    return firestore.doc(path);
  }

  @override
  Object? encode(Object? value) => (value as DocumentReference).path;

  @override
  Object? decode(Object? encoded) => firestore.doc(encoded as String);
}

/// The types a firestore document is edited with: the basic ones plus
/// [Timestamp], [Blob], [GeoPoint] and [DocumentReference].
///
/// A document reference resolves against [firestore], which is why this is a
/// function rather than a constant.
ObjectTypeRegistry firestoreObjectTypeRegistry(Firestore firestore) =>
    defaultObjectTypeRegistry.withHandlers([
      const FirestoreTimestampTypeHandler(),
      const FirestoreBlobTypeHandler(),
      const FirestoreGeoPointTypeHandler(),
      FirestoreDocumentReferenceTypeHandler(firestore),
    ]);

/// One firestore document.
class FirestoreObjectSource extends ObjectSource {
  /// The instance the document lives in.
  final Firestore firestore;

  /// The full path of the document (`users/123`).
  final String path;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Source of the document at [path].
  FirestoreObjectSource({
    required this.firestore,
    required this.path,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? firestoreObjectTypeRegistry(firestore);

  DocumentReference get _ref => firestore.doc(path);

  @override
  String get title => path;

  @override
  Future<Object?> read() async {
    var snapshot = await _ref.get();
    return snapshot.exists ? snapshot.data : null;
  }

  @override
  Future<void> write(
    Object? value, {
    List<ObjectEditOperation>? operations,
  }) async {
    checkWritable();
    if (value is! Map) {
      throw ArgumentError.value(
        value,
        'value',
        'A firestore document is a map',
      );
    }
    await _ref.set(value.map((key, value) => MapEntry('$key', value)));
  }

  @override
  Stream<Object?> watch() => _ref.onSnapshot().map(
    (snapshot) => snapshot.exists ? snapshot.data : null,
  );

  @override
  Future<void> delete() {
    checkWritable('delete $title');
    return _ref.delete();
  }
}

/// One firestore collection.
class FirestoreObjectCollection extends ObjectCollection {
  /// The instance the collection lives in.
  final Firestore firestore;

  /// The full path of the collection (`users`, `users/123/posts`).
  final String path;

  @override
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Collection of the documents at [path].
  FirestoreObjectCollection({
    required this.firestore,
    required this.path,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : typeRegistry = typeRegistry ?? firestoreObjectTypeRegistry(firestore);

  @override
  String get name => path;

  Query _query({int? limit}) {
    var collection = firestore.collection(path);
    return limit == null ? collection : collection.limit(limit);
  }

  @override
  Future<List<String>> listIds({int? limit}) async {
    var snapshot = await _query(limit: limit).get();
    return snapshot.docs.map((doc) => doc.ref.id).toList();
  }

  @override
  Stream<List<String>> watchIds({int? limit}) => _query(limit: limit)
      .onSnapshot()
      .map((snapshot) => snapshot.docs.map((doc) => doc.ref.id).toList());

  @override
  ObjectSource source(String id) => FirestoreObjectSource(
    firestore: firestore,
    path: '$path/$id',
    typeRegistry: typeRegistry,
    isReadOnly: isReadOnly,
  );

  @override
  Future<String> add(Object? value) async {
    checkWritable('add to $name');
    if (value is! Map) {
      throw ArgumentError.value(
        value,
        'value',
        'A firestore document is a map',
      );
    }
    var ref = await firestore
        .collection(path)
        .add(value.map((key, value) => MapEntry('$key', value)));
    return ref.id;
  }
}

/// A firestore instance or document, the collections under it.
///
/// Listing collections needs `FirestoreService.supportsListCollections`;
/// pass [collectionPaths] for a backend that does not support it (the rest
/// api, a client sdk), the paths then being the ones the app knows about.
class FirestoreObjectRepository extends ObjectRepository {
  /// The instance.
  final Firestore firestore;

  /// The document the collections sit under, null for the root ones.
  final String? documentPath;

  /// The collection paths to show instead of listing them.
  final List<String>? collectionPaths;

  @override
  final String title;

  /// The types the documents are edited with.
  final ObjectTypeRegistry typeRegistry;

  @override
  final bool isReadOnly;

  /// Repository of the collections of [firestore], under [documentPath] when
  /// one is given.
  FirestoreObjectRepository(
    this.firestore, {
    this.documentPath,
    this.collectionPaths,
    String? title,
    ObjectTypeRegistry? typeRegistry,
    this.isReadOnly = false,
  }) : title = title ?? documentPath ?? 'firestore',
       typeRegistry = typeRegistry ?? firestoreObjectTypeRegistry(firestore);

  @override
  Future<List<ObjectCollection>> listCollections() async {
    var paths = collectionPaths;
    if (paths == null) {
      var documentPath = this.documentPath;
      var refs = documentPath == null
          ? await firestore.listCollections()
          : await firestore.doc(documentPath).listCollections();
      paths = refs.map((ref) => ref.path).toList();
    }
    return paths
        .map(
          (path) => FirestoreObjectCollection(
            firestore: firestore,
            path: path,
            typeRegistry: typeRegistry,
            isReadOnly: isReadOnly,
          ),
        )
        .toList();
  }
}
