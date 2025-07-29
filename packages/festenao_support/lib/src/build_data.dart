// ignore_for_file: avoid_print

import 'dart:io';

// ignore: implementation_imports
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/data/festenao_sync.dart';
import 'package:festenao_common/firebase/firebase_service_account.dart';
import 'package:festenao_support/festenao_support.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:sembast/utils/database_utils.dart';
import 'package:sembast/utils/sembast_import_export.dart';

/// Build the database from firestore
Future<FestenaoDb> buildDatabaseFromFirestore({
  required String rootPath,
  required Map serviceAccount,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  var db = FestenaoDb.newInMemory();
  await databaseFromFirestore(
    db: db,
    rootPath: rootPath,
    serviceAccount: serviceAccount,
  );
  return db;
}

/// Get the database from firestore using a service account
Future<void> databaseFromFirestore({
  required FestenaoDb db,
  required String rootPath,
  required Map serviceAccount,
}) async {
  // ignore: invalid_use_of_visible_for_testing_member
  var context = await festenaoInitFirebaseWithServiceAccount(
    serviceAccountMap: serviceAccount,
  );
  var source = FestenaoSourceFirestore(
    firestore: context.firestore,
    rootPath: rootPath,
    noAuth: true,
  );
  var sync = FestenaoDbSourceSync(db: db, source: source);
  // Full sync
  var stat = await sync.syncDown();
  print(stat);
}

/// Export the database
Future<void> festenaoExportDatabase({
  required FestenaoDb db,
  required String assetsFolder,
}) async {
  await Directory(
    join(assetsFolder, festenaoImgSubDir),
  ).create(recursive: true);
  var file = File(join(assetsFolder, festenaoExport));
  var fileMeta = File(join(assetsFolder, festenaoExportMeta));

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
Future<FestenaoDb> festenaoImportDatabase({
  required String assetsFolder,
}) async {
  var factory = newDatabaseFactoryMemory();
  var file = File(join(assetsFolder, festenaoExport));
  var data = await file.readAsString();
  var db = await importDatabaseAny(data, factory, festenaoDbName);

  print(file);

  print(file.statSync());
  await db.close();
  return FestenaoDb(factory, name: festenaoDbName);
}

/// Build the data to the application
Future<void> buildData({
  required String assetsFolder,
  required Map serviceAccount,
  required String rootPath,
  // For now only clean the json files, not the attachments
  bool clean = false,
}) async {
  // init builders
  // ignore: invalid_use_of_visible_for_testing_member
  await FestenaoDb.newInMemory().database;
  await Directory(assetsFolder).create(recursive: true);
  // debugFaoSync = true;
  late FestenaoDb db;
  if (clean) {
    try {
      await File(join(assetsFolder, festenaoExport)).delete();
    } catch (_) {}
    try {
      await File(join(assetsFolder, festenaoExportMeta)).delete();
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
    db = FestenaoDb.newInMemory();
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
    var ioFile = File(join(assetsFolder, festenaoImgSubDir, imageName));
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
