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

  /// Firebase db options
  FestenaoSyncSourceOptions({
    required this.firebaseProjectId,
    required this.storageBucket,
    required this.firestoreRoot,
    required this.storageRoot,
  });

  @override
  String toString() {
    return 'FestenaoSyncSourceOptions(firebaseProjectId: $firebaseProjectId, storageBucket: $storageBucket, firestoreRoot: $firestoreRoot, storageRoot: $storageRoot)';
  }
}
