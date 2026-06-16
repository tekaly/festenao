import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// Database record for a folder history item.
class SdbFolderHistoryItem extends ScvStringRecordBase {
  /// The folder ID or URL.
  final folderId = CvField<String>('folderId');

  /// Timestamp when it was entered.
  final timestamp = CvField<int>('timestamp');

  @override
  CvFields get fields => [folderId, timestamp];
}

/// SDB database manager for storing folder picker history.
class FolderHistorySdb {
  /// Database factory.
  final SdbFactory factory;

  /// Name of the database.
  final String? name;

  /// The database instance.
  late final SdbDatabase db;

  /// Future that completes when the database is ready.
  late final Future<void> ready = () async {
    db = await factory.openDatabase(
      name ?? 'folder_history_v1.db',
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: SdbDatabaseSchema(stores: [dbFolderHistoryStore.schema()]),
      ),
    );
    cvAddConstructors([SdbFolderHistoryItem.new]);
  }();

  /// Sembast store for history items.
  static final dbFolderHistoryStore = scvStringStoreFactory
      .store<SdbFolderHistoryItem>('folder_history');

  /// Constructor.
  FolderHistorySdb({required this.factory, this.name});

  /// In-memory helper constructor.
  FolderHistorySdb.inMemory()
    : this(factory: sdbFactoryMemory, name: 'in_memory');

  /// Add a folder ID/URL to history, keeping only the last 100 entries.
  Future<void> addFolderId(String folderId) async {
    await ready;
    var item = SdbFolderHistoryItem()
      ..folderId.v = folderId
      ..timestamp.v = DateTime.now().millisecondsSinceEpoch;

    await db.inStoreTransaction(
      dbFolderHistoryStore.rawRef,
      SdbTransactionMode.readWrite,
      (txn) async {
        await dbFolderHistoryStore.record(folderId).put(txn, item);

        // Fetch all items, sort by timestamp desc, and trim to last 100
        var items = await dbFolderHistoryStore.findRecords(txn);
        if (items.length > 100) {
          var sorted = List<SdbFolderHistoryItem>.from(items)
            ..sort((a, b) => b.timestamp.v!.compareTo(a.timestamp.v!));

          for (var i = 100; i < sorted.length; i++) {
            await dbFolderHistoryStore
                .record(sorted[i].folderId.v!)
                .delete(txn);
          }
        }
      },
    );
  }

  /// Get the list of latest folder IDs/URLs sorted by last-entered first.
  Future<List<String>> getLatestFolderIds() async {
    await ready;
    var items = await dbFolderHistoryStore.findRecords(db);
    var sorted = List<SdbFolderHistoryItem>.from(items)
      ..sort((a, b) => b.timestamp.v!.compareTo(a.timestamp.v!));
    return sorted.map((e) => e.folderId.v!).toList();
  }

  /// Close the database connection.
  Future<void> close() async {
    await ready;
    await db.close();
  }
}
