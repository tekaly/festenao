import 'package:tekaly_sdb_synced/synced_source.dart'
    show SyncedSourcePartition;

/// FestenaoDb options
class FestenaoSyncSourceOptions {
  /// Firebase project id
  final String firebaseProjectId;

  /// Storage bucket
  final String storageBucket;

  /// Firestore root path (doc)
  final String firestoreRoot;

  /// Storage root path (could match firestore)
  final String storageRoot;

  /// The partition of the records (a user id field), if any: only the
  /// records of its value are synchronized down (sdb only).
  final SyncedSourcePartition? partition;

  /// Firebase db options
  FestenaoSyncSourceOptions({
    required this.firebaseProjectId,
    required this.storageBucket,
    required this.firestoreRoot,
    required this.storageRoot,
    this.partition,
  });

  @override
  String toString() {
    return 'FestenaoSyncSourceOptions(firebaseProjectId: $firebaseProjectId, storageBucket: $storageBucket, firestoreRoot: $firestoreRoot, storageRoot: $storageRoot${partition == null ? '' : ', partition: $partition'})';
  }
}
