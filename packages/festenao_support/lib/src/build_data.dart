// ignore_for_file: avoid_print
import 'dart:io' as io;
import 'dart:io';

// ignore: implementation_imports
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/data/festenao_sync.dart';
import 'package:festenao_common/data/src/model/db_models.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firebase_service_account.dart';
import 'package:festenao_support/festenao_support.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';
import 'package:tekaly_sembast_synced/synced_db_storage.dart';
import 'package:tkcms_common/tkcms_storage.dart';

/// Build the database from firestore
Future<SyncedDb> buildDatabaseFromFirestore({
  required String rootPath,
  required Map serviceAccount,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  var db = SyncedDb.newInMemory();
  await databaseFromFirestore(
    db: db,
    rootPath: rootPath,
    serviceAccount: serviceAccount,
  );
  return db;
}

/// Get the database from firestore using a service account
Future<void> databaseFromFirestore({
  required SyncedDb db,
  Firestore? firestore,
  required String rootPath,
  Map? serviceAccount,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  if (firestore == null && serviceAccount == null) {
    throw ArgumentError('Either firestore or serviceAccount must be provided');
  }
  if (firestore == null) {
    if (serviceAccount == null) {
      throw ArgumentError(
        'Either firestore or serviceAccount must be provided',
      );
    } else {
      var context = await festenaoInitFirebaseWithServiceAccount(
        serviceAccountMap: serviceAccount,
      );
      firestore = context.firestore;
    }
  }

  var source = FestenaoSourceFirestore(
    firestore: firestore,
    rootPath: rootPath,
  );
  var sync = FestenaoDbSourceSync(db: db, source: source);
  // Full sync
  var stat = await sync.syncDown();
  print(stat);
}

/// Export the database
Future<void> festenaoExportDatabase({
  required SyncedDb db,
  io.Directory? directory,
  String? assetsFolder,
}) async {
  var dir = directory ?? io.Directory(assetsFolder!);
  var dirPath = dir.path;
  await Directory(join(dirPath, festenaoImgSubDir)).create(recursive: true);
  var file = io.File(join(dirPath, festenaoExport));
  var fileMeta = io.File(join(dirPath, festenaoExportMeta));

  var sdb = await db.database;
  var lines = await exportDatabaseLines(
    sdb,
    storeNames: getNonEmptyStoreNames(sdb).toList()
      ..removeWhere((element) => [dbSyncRecordStoreRef.name].contains(element)),
  );
  //print(jsonPretty(map));
  // ignore: invalid_use_of_visible_for_testing_member
  var syncMeta = (await db.getSyncMetaInfo());
  if (syncMeta != null) {
    await file.writeAsString(exportLinesToJsonStringList(lines).join('\n'));
    var exportMeta = FestenaoExportMeta()
      ..sourceVersion.setValue(syncMeta.sourceVersion.v)
      ..lastTimestamp.setValue(syncMeta.lastTimestamp.v?.toIso8601String())
      ..lastChangeId.setValue(syncMeta.lastChangeId.v);
    //print(jsonPretty(exportMeta.toModel()));
    await fileMeta.writeAsString(jsonEncode(exportMeta.toMap()));
  }
}

/// Import a database from .jsonl
Future<SyncedDb> festenaoImportDatabase({
  /// Prefer
  Directory? directory,
  String? assetsFolder,
}) async {
  directory ??= io.Directory(assetsFolder!);
  var dirPath = directory.path;
  var factory = newDatabaseFactoryMemory();
  var file = io.File(join(dirPath, festenaoExport));
  var data = await file.readAsString();
  var db = await importDatabaseAny(data, factory, festenaoDbName);

  print(file);

  print(file.statSync());
  await db.close();
  return SyncedDb(databaseFactory: factory, name: festenaoDbName);
}

/// Builder to export/import local data
class FestenaoExportLocalBuilder {
  /// Export the database
  Future<void> exportLocal({
    required SyncedDb db,
    required io.Directory directory,
  }) async {
    var dirPath = directory.path;
    await Directory(join(dirPath, festenaoImgSubDir)).create(recursive: true);
    var file = io.File(join(dirPath, festenaoExport));
    var fileMeta = io.File(join(dirPath, festenaoExportMeta));

    var sdb = await db.database;
    var lines = await exportDatabaseLines(
      sdb,
      storeNames: getNonEmptyStoreNames(sdb).toList()
        ..removeWhere(
          (element) => [dbSyncRecordStoreRef.name].contains(element),
        ),
    );
    print(jsonPretty(lines));
    // ignore: invalid_use_of_visible_for_testing_member
    var syncMeta = (await db.getSyncMetaInfo());
    print('syncMeta $syncMeta $file');
    if (syncMeta != null) {
      print('exporting to $file');
      await file.writeAsString(exportLinesToJsonStringList(lines).join('\n'));
      var exportMeta = FestenaoExportMeta()
        ..sourceVersion.setValue(syncMeta.sourceVersion.v)
        ..lastTimestamp.setValue(syncMeta.lastTimestamp.v?.toIso8601String())
        ..lastChangeId.setValue(syncMeta.lastChangeId.v);
      //print(jsonPretty(exportMeta.toModel()));
      await fileMeta.writeAsString(jsonEncode(exportMeta.toMap()));
    }
  }

  /// Import a database from .jsonl
  Future<SyncedDb> importLocal({required Directory directory}) async {
    var dirPath = directory.path;
    var factory = newDatabaseFactoryMemory();
    var file = io.File(join(dirPath, festenaoExport));
    var data = await file.readAsString();
    var db = await importDatabaseAny(data, factory, festenaoDbName);

    print(file);

    print(file.statSync());
    await db.close();
    return SyncedDb(databaseFactory: factory, name: festenaoDbName);
  }

  /// Build the data to the application
  Future<void> storageBuildData({
    required FirebaseStorageContext firebaseStorageContext,
    Directory? directory,
    // For now only clean the json files, not the attachments
    bool? clean,

    /// '_dev' etc.
    String? metaBasenameSuffix,
  }) async {
    clean ??= false;
    //...database;
    var bucketName =
        firebaseStorageContext.bucketName ??
        firebaseStorageContext.storage.app.options.storageBucket;
    directory ??= io.Directory(
      join(
        '.local',
        'firebase_storage',
        firebaseStorageContext.projectId,
        bucketName,
        firebaseStorageContext.dirBasename,
      ),
    );
    await directory.create(recursive: true);

    await _directoryPrepare(clean: clean, directory: directory);
    var db = await _importLocal(directory: directory);

    await db.importDatabaseFromStorage(
      importContext: SyncedDbStorageImportExportContext(
        storage: firebaseStorageContext.storage,
        bucketName: firebaseStorageContext.bucketName,
        rootPath: url.join(
          firebaseStorageContext.rootDirectory,
          storageDataDirPart,
        ),
        metaBasenameSuffix: metaBasenameSuffix,
      ),
    );
    await exportLocal(db: db, directory: directory);
    await _importImagesFromStorage(
      firebaseStorageContext: firebaseStorageContext,
      directory: directory,
      db: db,
    );
  }

  /// Get the database from firestore using a service account
  Future<void> _syncDownFromFirestore({
    required SyncedDb db,
    required FirestoreDatabaseContext firestoreDatabaseContext,
  }) async {
    var source = FestenaoSourceFirestore(
      firestore: firestoreDatabaseContext.firestore,
      rootPath: firestoreDatabaseContext.rootDocumentPath,
    );
    var sync = FestenaoDbSourceSync(db: db, source: source);
    // Full sync
    var stat = await sync.syncDown();
    print(stat);
  }

  Future<SyncedDb> _importLocal({required Directory directory}) async {
    SyncedDb db;
    try {
      // Read the existing to compare
      db = await importLocal(directory: directory);
      print((await db.database).version);
      // ignore: invalid_use_of_visible_for_testing_member
      var meta = await db.getSyncMetaInfo();
      print('imported meta ${jsonPretty(meta?.toMap())}');
    } catch (e) {
      print(e);
      // ignore: invalid_use_of_visible_for_testing_member
      db = SyncedDb.newInMemory();
      print((await db.database).version);
    }
    // ignore: invalid_use_of_visible_for_testing_member
    var meta = await db.getSyncMetaInfo();
    print('meta $meta');
    return db;
  }

  /// Build the data to the application
  Future<void> firestoreBuildData({
    required FirebaseStorageContext firebaseStorageContext,
    required FirestoreDatabaseContext firestoreDatabaseContext,

    /// Output directory
    Directory? directory,

    // For now only clean the json files, not the attachments
    bool clean = false,
  }) async {
    var bucketName =
        firebaseStorageContext.bucketName ??
        firebaseStorageContext.storage.app.options.storageBucket;
    directory ??= io.Directory(
      join(
        '.local',
        'firestore',
        firebaseStorageContext.projectId,
        bucketName, // updated from firebaseStorageContext.bucketName,
        firebaseStorageContext.dirBasename,
      ),
    );
    await _directoryPrepare(clean: clean, directory: directory);
    var db = await _importLocal(directory: directory);

    await _syncDownFromFirestore(
      db: db,
      firestoreDatabaseContext: firestoreDatabaseContext,
    );
    // ignore: invalid_use_of_visible_for_testing_member

    await exportLocal(db: db, directory: directory);
    // ignore: invalid_use_of_visible_for_testing_member
    var meta = await db.getSyncMetaInfo();
    print('meta $meta');
    await _importImagesFromStorage(
      firebaseStorageContext: firebaseStorageContext,
      directory: directory,
      db: db,
    );
  }

  Future<void> _importImagesFromStorage({
    required FirebaseStorageContext firebaseStorageContext,
    required io.Directory directory,
    required SyncedDb db,
  }) async {
    initFestenaoDbBuilders();
    var dirPath = directory.path;
    var database = await db.database;
    var dbImages = await dbImageStoreRef.find(database);

    print(dbImages);
    var storage = firebaseStorageContext.storage;
    var bucket = storage.bucket(firebaseStorageContext.bucketName);
    var gsRootDir = firebaseStorageContext.rootDirectory;

    for (var dbImage in dbImages) {
      var imageName = dbImage.name.v;
      // TEMP! to remove
      // var imageName = 'artist_${dbImage.name.v}';
      var ioFile = io.File(join(dirPath, festenaoImgSubDir, imageName));
      if (!ioFile.existsSync()) {
        var file = bucket.file(
          url.join(gsRootDir, storageImageDirPart, imageName),
        );
        // devPrint('${bucket.name} ${file.name}');
        try {
          var bytes = await file.readAsBytes();

          await ioFile.writeAsBytes(bytes);
          print('wrote image $imageName');
        } catch (e) {
          print('fail for $imageName $e');
        }
      }
    }

    /*
  var db = await buildDatabaseFromFirestore(rootPath: rootPath);
  await festenaoExportDatabase(db: db, assetsFolder: _assetsFolder);

   */
  }

  Future<void> _directoryPrepare({
    required bool clean,
    required io.Directory directory,
  }) async {
    await directory.create(recursive: true);
    var dirPath = directory.path;
    // debugFaoSync = true;
    if (clean) {
      try {
        await io.File(join(dirPath, festenaoExport)).delete();
      } catch (_) {}
      try {
        await io.File(join(dirPath, festenaoExportMeta)).delete();
      } catch (_) {}
    }
  }
}

/// Build the data to the application
Future<void> buildData({
  /// Compat
  required String assetsFolder,
  required Map serviceAccount,
  required String rootPath,
  // For now only clean the json files, not the attachments
  bool clean = false,
}) async {
  // init builders
  // ignore: invalid_use_of_visible_for_testing_member
  await SyncedDb.newInMemory().database;

  await io.Directory(assetsFolder).create(recursive: true);
  // debugFaoSync = true;
  late SyncedDb db;
  if (clean) {
    try {
      await io.File(join(assetsFolder, festenaoExport)).delete();
    } catch (_) {}
    try {
      await io.File(join(assetsFolder, festenaoExportMeta)).delete();
    } catch (_) {}
  }

  try {
    db = await festenaoImportDatabase(assetsFolder: assetsFolder);
    print((await db.database).version);
    // ignore: invalid_use_of_visible_for_testing_member
    var meta = await db.getSyncMetaInfo();
    print('imported meta ${jsonPretty(meta?.toMap())}');
  } catch (e) {
    print(e);
    // ignore: invalid_use_of_visible_for_testing_member
    db = SyncedDb.newInMemory();
    print((await db.database).version);
  }
  // ignore: invalid_use_of_visible_for_testing_member
  var meta = await db.getSyncMetaInfo();
  print('meta $meta');
  await databaseFromFirestore(
    db: db,
    rootPath: rootPath,
    serviceAccount: serviceAccount,
  );
  // ignore: invalid_use_of_visible_for_testing_member
  meta = await db.getSyncMetaInfo();
  await festenaoExportDatabase(db: db, assetsFolder: assetsFolder);
  // ignore: invalid_use_of_visible_for_testing_member
  meta = await db.getSyncMetaInfo();
  print('meta $meta');
  var database = await db.database;
  var dbImages = await dbImageStoreRef.find(database);
  var context = await festenaoInitFirebaseWithServiceAccount(
    serviceAccountMap: serviceAccount,
  );

  print(dbImages);
  for (var dbImage in dbImages) {
    var imageName = dbImage.name.v;
    // TEMP! to remove
    // var imageName = 'artist_${dbImage.name.v}';
    var ioFile = io.File(join(assetsFolder, festenaoImgSubDir, imageName));
    if (!ioFile.existsSync()) {
      var bucketName = context.projectId;
      var bucket = context.storage.bucket('$bucketName.appspot.com');
      var file = bucket.file(
        url.join(rootPath, storageImageDirPart, imageName),
      );
      // devPrint('${bucket.name} ${file.name}');
      try {
        var bytes = await file.readAsBytes();

        await ioFile.writeAsBytes(bytes);
        print('wrote image $imageName');
      } catch (e) {
        print('fail for $imageName $e');
      }
    }
  }

  /*
  var db = await buildDatabaseFromFirestore(rootPath: rootPath);
  await festenaoExportDatabase(db: db, assetsFolder: _assetsFolder);

   */
}
