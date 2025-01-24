import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_firestore.dart' as fs;
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
// ignore: depend_on_referenced_packages
import 'package:tekaly_sembast_synced/synced_db_internals.dart';
import 'package:tekaly_sembast_synced/synced_db_storage.dart';
import 'package:tkcms_admin_app/sembast/content_db_bloc.dart';
import 'package:tkcms_common/tkcms_content.dart';

class AdminExportEditScreenBlocState {
  final FsExport? fsExport;
  final DbSyncMetaInfo metaInfo;

  AdminExportEditScreenBlocState({this.fsExport, required this.metaInfo});
}

class AdminExportEditData {
  final FsExport fsExport;
  final bool export;
  final bool publishDev;
  final bool publish;

  AdminExportEditData(
      {required this.fsExport,
      this.export = false,
      this.publishDev = false,
      this.publish = false});
}

class AdminExportEditScreenBloc extends BaseBloc {
  final FestenaoAdminAppProjectContext projectContext;

  ByProjectIdAdminAppProjectContext get byIdProjectContext =>
      (projectContext as ByProjectIdAdminAppProjectContext);

  String get projectId => byIdProjectContext.projectId;
  final String? exportId;
  final _state = BehaviorSubject<AdminExportEditScreenBlocState>();

  Firestore get firestore => projectContext.firestore;
  late var storage = globalFirebaseContext.storage;

  String get firestoreExportCollectionPath =>
      join(_firestoreRootPath, firestoreExportPathPart);

  String get firestoreMetaCollectionPath =>
      join(_firestoreRootPath, firestoreExportMetaPathPart);

  String get _firestoreRootPath => projectContext.firestorePath;

  //late var exportFirestoreRootPath = projectContext.firestorePath;

  String get exportStorageDirPath =>
      join(projectContext.storagePath, storageDataPathPart);
  late ContentDb festenaoDb;

  ValueStream<AdminExportEditScreenBlocState> get state => _state;

  AdminExportEditScreenBloc(
      {required this.projectContext, required this.exportId}) {
    var projectContext = this.projectContext;
    () async {
      try {
        DbSyncMetaInfo metaInfo;
        if (kDebugMode) {
          print(
              'firestoreExportCollectionPath: $firestoreExportCollectionPath');
          print('storageRootPath: $exportStorageDirPath');
        }
        if (projectContext is SingleFestenaoAdminAppProjectContext) {
          var festenaoDb = projectContext.syncedDb;
          metaInfo = (await festenaoDb.getSyncMetaInfo())!;
        } else {
          festenaoDb = await globalContentBloc.grabContentDb(projectId);
          metaInfo = (await festenaoDb.syncedDb.getSyncMetaInfo())!;
        }
        if (exportId == null) {
          // Creation

          var changeId = metaInfo.lastChangeId.v!;
          // Find existing export
          var fsExport = (await firestore
                  .collection(firestoreExportCollectionPath)
                  .where(fsExportModel.changeId.name, isEqualTo: changeId)
                  .cvGet<FsExport>())
              .firstOrNull;
          fsExport ??= FsExport()
            ..changeId.fromCvField(metaInfo.lastChangeId)
            ..version.fromCvField(metaInfo.sourceVersion);
          _state.add(AdminExportEditScreenBlocState(
              fsExport: fsExport, metaInfo: metaInfo));
        } else {
          var export = await firestore.cvGet<FsExport>(
              url.join(firestoreExportCollectionPath, exportId));
          _state.add(AdminExportEditScreenBlocState(
              fsExport: export, metaInfo: metaInfo));
        }
      } catch (e, st) {
        if (kDebugMode) {
          print(e);
          print(st);
        }
        _state.addError(e);
        return;
      }
    }();
  }

  Future<void> save(AdminExportEditData data) async {
    var projectContext = this.projectContext;
    var fsExport = data.fsExport;
    var exportId = fsExport.idOrNull;
    var changeId = fsExport.changeId.v!;

    var export = data.export;
    exportId ??=
        (await firestore.cvAdd(firestoreExportCollectionPath, fsExport)).id;

    if (kDebugMode) {
      print('firestoreExportCollectionPath: $firestoreExportCollectionPath');
      print('storageRootPath: $exportStorageDirPath');
    }

    SyncedDb syncedDb;
    if (projectContext is SingleFestenaoAdminAppProjectContext) {
      syncedDb = projectContext.syncedDb;
    } else {
      festenaoDb = await globalContentBloc.grabContentDb(projectId);
      syncedDb = festenaoDb.syncedDb;
    }
    // var exportInfo = await syncedDb.exportInMemory();
    if (export) {
      fsExport.size.v = (await syncedDb.exportDatabaseToStorage(
              exportContext: SyncedDbStorageExportContext(
                  storage: projectContext.storage,
                  rootPath: exportStorageDirPath),
              noMeta: true))
          .exportSize;
    }
    var meta = FestenaoExportMeta()
      ..lastChangeId.fromCvField(fsExport.changeId)
      ..sourceVersion.fromCvField(fsExport.version)
      ..lastTimestamp.v = Timestamp.now().toIso8601String();

    Future<void> writeFirestoreMeta(String path) async {
      await firestore.doc(path).set(meta.toMap());
    }

    var firestoreInfoPath = firestoreMetaCollectionPath;
    if (data.publishDev) {
      await writeFirestoreMeta(url.join(
          firestoreInfoPath, getFirestorePublishMetaDocumentName(true)));
      await syncedDb.exportDatabaseToStorage(
          exportContext: SyncedDbStorageExportContext(
              storage: projectContext.storage,
              rootPath: exportStorageDirPath,
              metaBasenameSuffix: '_dev'),
          metaOnly: true);
    }
    if (data.publish) {
      await writeFirestoreMeta(url.join(
          firestoreInfoPath, getFirestorePublishMetaDocumentName(false)));
      await syncedDb.exportDatabaseToStorage(
          exportContext: SyncedDbStorageExportContext(
              storage: projectContext.storage, rootPath: exportStorageDirPath),
          metaOnly: true);
    }
    var map = fsExport.toMap();
    // Set timestamp
    map[fsExportModel.timestamp.name] = fs.FieldValue.serverTimestamp;

    // Delete other
    var toDelete = <String?>[];
    var existingExports = await firestore
        .collection(firestoreExportCollectionPath)
        .where(fsExportModel.changeId.name, isEqualTo: changeId)
        .cvGet<FsExport>();
    for (var export in existingExports) {
      if (export.id != exportId) {
        toDelete.add(export.id);
      }
    }
    await firestore.cvRunTransaction((transaction) {
      for (var id in toDelete) {
        transaction.delete(
          firestore.doc(url.join(firestoreExportCollectionPath, id!)),
        );
      }
      transaction.set(
          firestore.doc(url.join(firestoreExportCollectionPath, exportId!)),
          map,
          SetOptions(merge: true));
    });
  }

  @override
  void dispose() {
    _state.close();
    super.dispose();
  }
}
