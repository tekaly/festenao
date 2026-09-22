import 'dart:convert';

import 'package:idb_shim/sdb.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';

import '../data/model/object_source_firestore.dart';
import '../data/model/object_type_registry.dart';

/// The marker of a firestore backup, and the version of its format.
const firestoreBackupFormatKey = 'festenao_firestore_backup';

/// The version this writes, and the one it reads.
const firestoreBackupFormatVersion = 1;

/// A firestore tree, read out whole.
///
/// It is **flat**: every document is held under its full path, so the shape of
/// the tree is in the keys rather than in the nesting. That is what makes a
/// backup easy to read, to diff and to restore — a document goes back where
/// its path says, whatever is above it.
class FirestoreBackupData {
  /// The documents, by their full path, in the order they were read.
  ///
  /// The values are the runtime ones, so a `Timestamp` is a `Timestamp`; they
  /// reach json through [FirestoreBackup.toJsonEncodable].
  final Map<String, Map<String, Object?>> documents;

  /// Where the backup was taken from, null for a whole instance.
  final String? rootPath;

  /// When it was taken.
  final DateTime takenAt;

  /// Backup holding [documents].
  FirestoreBackupData({
    required this.documents,
    this.rootPath,
    DateTime? takenAt,
  }) : takenAt = takenAt ?? DateTime.now().toUtc();

  /// How many documents it holds.
  int get documentCount => documents.length;

  /// The collections the documents sit in, sorted, deepest ones included.
  List<String> get collectionPaths {
    var paths = <String>{};
    for (var path in documents.keys) {
      var parts = path.split('/');
      // A document path has an even number of parts, its collection is
      // everything but the last one.
      if (parts.length >= 2) {
        paths.add(parts.sublist(0, parts.length - 1).join('/'));
      }
    }
    return paths.toList()..sort();
  }

  /// The documents of the collection [path], by their id.
  Map<String, Map<String, Object?>> collectionDocuments(String path) {
    var prefix = '$path/';
    return {
      for (var entry in documents.entries)
        if (entry.key.startsWith(prefix) &&
            !entry.key.substring(prefix.length).contains('/'))
          entry.key.substring(prefix.length): entry.value,
    };
  }

  @override
  String toString() =>
      'FirestoreBackupData(${rootPath ?? '/'}, $documentCount documents)';
}

/// Reads a firestore tree out whole, and puts it back.
///
/// It walks the sub collections of every document it reads, so a backup of a
/// collection is the collection and everything below it.
///
/// ```dart
/// var backup = FirestoreBackup(firestore: firestore);
/// var data = await backup.readCollection('users');
/// await explorer.writeAsString('users.json', backup.toJsonText(data));
/// ```
///
/// Walking the sub collections needs `FirestoreService.supportsListCollections`;
/// without it the backup holds the documents it was pointed at and nothing
/// below them, which [FirestoreBackup.walksSubCollections] says up front.
class FirestoreBackup {
  /// The instance being read.
  final Firestore firestore;

  /// The types the values are encoded through, the firestore ones by default.
  final ObjectTypeRegistry typeRegistry;

  /// How deep the walk goes, a document and its sub collections counting as
  /// one level.
  final int maxDepth;

  /// Backup of [firestore].
  FirestoreBackup({
    required this.firestore,
    ObjectTypeRegistry? typeRegistry,
    this.maxDepth = 20,
  }) : typeRegistry = typeRegistry ?? firestoreObjectTypeRegistry(firestore);

  /// Whether the sub collections of a document can be walked here.
  bool get walksSubCollections => firestore.service.supportsListCollections;

  /// Reads the collection [path] and everything below it.
  ///
  /// [limit] caps the documents read per collection, for a first look at a
  /// large one.
  Future<FirestoreBackupData> readCollection(
    String path, {
    int? limit,
    int? maxDepth,
  }) async {
    var documents = <String, Map<String, Object?>>{};
    await _readCollection(
      path,
      documents,
      limit: limit,
      depth: maxDepth ?? this.maxDepth,
    );
    return FirestoreBackupData(documents: documents, rootPath: path);
  }

  /// Reads the document [path] and everything below it.
  Future<FirestoreBackupData> readDocument(String path, {int? maxDepth}) async {
    var documents = <String, Map<String, Object?>>{};
    await _readDocument(path, documents, depth: maxDepth ?? this.maxDepth);
    return FirestoreBackupData(documents: documents, rootPath: path);
  }

  /// Reads every root collection, and everything below them.
  ///
  /// [collectionPaths] names them for a backend that cannot list them.
  Future<FirestoreBackupData> readAll({
    List<String>? collectionPaths,
    int? limit,
    int? maxDepth,
  }) async {
    var paths =
        collectionPaths ??
        (await firestore.listCollections()).map((ref) => ref.path).toList();
    var documents = <String, Map<String, Object?>>{};
    for (var path in paths) {
      await _readCollection(
        path,
        documents,
        limit: limit,
        depth: maxDepth ?? this.maxDepth,
      );
    }
    return FirestoreBackupData(documents: documents);
  }

  Future<void> _readCollection(
    String path,
    Map<String, Map<String, Object?>> documents, {
    required int depth,
    int? limit,
  }) async {
    if (depth <= 0) {
      return;
    }
    var collection = firestore.collection(path);
    var snapshot = await (limit == null ? collection : collection.limit(limit))
        .get();
    for (var doc in snapshot.docs) {
      documents[doc.ref.path] = doc.data;
      await _readSubCollections(doc.ref, documents, depth: depth - 1);
    }
  }

  Future<void> _readDocument(
    String path,
    Map<String, Map<String, Object?>> documents, {
    required int depth,
  }) async {
    if (depth <= 0) {
      return;
    }
    var ref = firestore.doc(path);
    var snapshot = await ref.get();
    if (snapshot.exists) {
      documents[path] = snapshot.data;
    }
    await _readSubCollections(ref, documents, depth: depth - 1);
  }

  Future<void> _readSubCollections(
    DocumentReference ref,
    Map<String, Map<String, Object?>> documents, {
    required int depth,
  }) async {
    if (depth <= 0 || !walksSubCollections) {
      return;
    }
    for (var collection in await ref.listCollections()) {
      await _readCollection(collection.path, documents, depth: depth);
    }
  }

  /// [data] as a json encodable map, the values encoded through
  /// [typeRegistry] — a timestamp, a blob, a geo point and a reference all
  /// survive the round trip.
  Map<String, Object?> toJsonEncodable(FirestoreBackupData data) => {
    firestoreBackupFormatKey: firestoreBackupFormatVersion,
    if (data.rootPath != null) 'root': data.rootPath,
    'takenAt': data.takenAt.toIso8601String(),
    'documents': {
      for (var entry in data.documents.entries)
        entry.key: typeRegistry.toJsonEncodable(entry.value),
    },
  };

  /// The backup back from what [toJsonEncodable] produced.
  ///
  /// Throws a [FormatException] on anything that is not one.
  FirestoreBackupData fromJsonEncodable(Object? json) {
    if (json is! Map) {
      throw const FormatException('Not a firestore backup');
    }
    var version = json[firestoreBackupFormatKey];
    if (version is! int) {
      throw const FormatException('Not a firestore backup');
    }
    if (version > firestoreBackupFormatVersion) {
      throw FormatException('Firestore backup version $version is too new');
    }
    var rawDocuments = json['documents'];
    if (rawDocuments is! Map) {
      throw const FormatException('The backup holds no documents');
    }
    var documents = <String, Map<String, Object?>>{};
    rawDocuments.forEach((path, value) {
      var decoded = typeRegistry.fromJsonEncodable(value);
      if (decoded is Map) {
        documents['$path'] = decoded.cast<String, Object?>();
      }
    });
    return FirestoreBackupData(
      documents: documents,
      rootPath: json['root'] as String?,
      takenAt:
          DateTime.tryParse('${json['takenAt']}')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  /// [data] as indented json text, what a backup file holds.
  String toJsonText(FirestoreBackupData data) =>
      '${const JsonEncoder.withIndent('  ').convert(toJsonEncodable(data))}\n';

  /// The backup the json [text] holds.
  FirestoreBackupData fromJsonText(String text) =>
      fromJsonEncodable(jsonDecode(text));

  /// Writes every document of [data] back into firestore, answering how many
  /// were written.
  ///
  /// Each one goes where its path says, replacing what is there. What is in
  /// firestore and not in the backup is left alone: this puts a backup back,
  /// it does not make firestore match it.
  Future<int> restore(FirestoreBackupData data) async {
    var count = 0;
    for (var entry in data.documents.entries) {
      await firestore.doc(entry.key).set(entry.value);
      count++;
    }
    return count;
  }
}

/// The name the sdb store of the collection [path] takes: the path itself.
///
/// A nested collection keeps its slashes — `users/1/posts` is the store
/// `users/1/posts` — since an sdb store name is any string, and keeping the
/// path is what lets the documents go back where they came from.
String firestoreBackupSdbStoreName(String path) => path;

/// The schema an sdb database holding [data] needs: one store per collection.
SdbDatabaseSchema firestoreBackupSdbSchema(FirestoreBackupData data) =>
    SdbDatabaseSchema(
      stores: [
        for (var path in data.collectionPaths)
          SdbStoreRef<String, SdbModel>(
            firestoreBackupSdbStoreName(path),
          ).schema(),
      ],
    );

/// Writes [data] into [database], a store per collection and a record per
/// document, keyed by its id.
///
/// The database must have been opened with [firestoreBackupSdbSchema].
Future<int> writeFirestoreBackupToSdb(
  FirestoreBackupData data,
  SdbDatabase database, {
  required ObjectTypeRegistry typeRegistry,
}) async {
  var count = 0;
  for (var path in data.collectionPaths) {
    var store = SdbStoreRef<String, SdbModel>(
      firestoreBackupSdbStoreName(path),
    );
    var documents = data.collectionDocuments(path);
    for (var entry in documents.entries) {
      await store
          .record(entry.key)
          .put(
            database,
            (typeRegistry.toJsonEncodable(entry.value) as Map)
                .cast<String, Object?>(),
          );
      count++;
    }
  }
  return count;
}

/// The backup an sdb database written by [writeFirestoreBackupToSdb] holds.
Future<FirestoreBackupData> readFirestoreBackupFromSdb(
  SdbDatabase database, {
  required ObjectTypeRegistry typeRegistry,
  String? rootPath,
}) async {
  var documents = <String, Map<String, Object?>>{};
  for (var storeName in database.storeNames) {
    var store = SdbStoreRef<String, SdbModel>(storeName);
    for (var snapshot in await store.findRecords(database)) {
      var decoded = typeRegistry.fromJsonEncodable(snapshot.value);
      if (decoded is Map) {
        documents['$storeName/${snapshot.key}'] = decoded
            .cast<String, Object?>();
      }
    }
  }
  return FirestoreBackupData(documents: documents, rootPath: rootPath);
}
