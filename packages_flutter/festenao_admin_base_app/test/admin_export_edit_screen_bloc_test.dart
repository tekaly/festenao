// ignore_for_file: invalid_use_of_protected_member
import 'dart:convert';

import 'package:festenao_admin_base_app/screen/admin_export_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tekaly_sembast_synced/synced_db_internals.dart';
import 'package:tkcms_common/tkcms_storage.dart';

const _root = 'app/a/project/p1';

/// A single project context on local (memory) services.
class _Ctx implements SingleFestenaoAdminAppProjectContext {
  _Ctx(this.syncedDb, this.firestore, this.storage);
  @override
  final SyncedDb syncedDb;
  @override
  final Firestore firestore;
  @override
  final FirebaseStorage storage;
  @override
  String get storageBucket => 'bucket';
  @override
  String get firestorePath => _root;
  @override
  String get storagePath => _root;
  @override
  String get projectId => 'p1';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _setChangeId(SyncedDb db, int changeId) async {
  await db.setSyncMetaInfo(
    null,
    DbSyncMetaInfo()
      ..lastChangeId.v = changeId
      ..sourceVersion.v = 1,
  );
}

void main() {
  initFestenaoFsBuilders();
  late _Ctx ctx;
  late SyncedDb syncedDb;
  setUp(() async {
    // Read by the db bloc dispose (none to release for a single project).
    globalProjectsDbBloc = ProjectsDbBloc();
    // Memory firestore and storage.
    var fbContext = await initFirebaseServicesLocalMemory(projectId: 'test')
        .init();
    syncedDb = SyncedDb.newInMemory(syncedStoreNames: ['artist']);
    ctx = _Ctx(syncedDb, fbContext.firestore, fbContext.storage);
  });
  tearDown(() async {
    await syncedDb.close();
  });

  var exports = '$_root/export';
  var firestoreMetaPath =
      '$_root/info/${getFirestorePublishMetaDocumentName(false)}';
  var storageMetaPath = p.url.join('$_root/data', 'export_meta.json');

  test(
    'an export that is not the current change cannot be published',
    () async {
      // Export 5 done earlier, the content moved on since (change 8).
      await _setChangeId(syncedDb, 5);
      await ctx.firestore.doc('$exports/e5').set({'changeId': 5, 'version': 1});
      await _setChangeId(syncedDb, 8);

      var bloc = AdminExportEditScreenBloc(projectContext: ctx, exportId: 'e5');
      var state = await bloc.state.first;
      expect(state.fsExport!.changeId.v, 5);
      // The switches of the screen for an older export: publish dev and prod.
      await expectLater(
        bloc.save(
          AdminExportEditData(
            fsExport: state.fsExport!,
            publish: true,
            publishDev: true,
          ),
        ),
        throwsStateError,
      );
      // Nothing published (the storage meta would name change 8, never
      // exported).
      expect(
        (await ctx.firestore.doc(firestoreMetaPath).get()).exists,
        isFalse,
      );
      expect(
        await ctx.storage.bucket('bucket').file(storageMetaPath).exists(),
        isFalse,
      );
      bloc.dispose();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('the export of the current change is exported and published', () async {
    await _setChangeId(syncedDb, 8);
    var bloc = AdminExportEditScreenBloc(projectContext: ctx, exportId: null);
    var state = await bloc.state.first;
    expect(state.fsExport!.changeId.v, 8);
    await bloc.save(
      AdminExportEditData(
        fsExport: state.fsExport!,
        export: true,
        publish: true,
      ),
    );
    var fsMeta = (await ctx.firestore.doc(firestoreMetaPath).get()).data;
    expect(fsMeta['lastChangeId'], 8);
    var storageMeta = jsonDecode(
      await ctx.storage.bucket('bucket').file(storageMetaPath).readAsString(),
    ) as Map;
    expect(storageMeta['lastChangeId'], 8);
    expect(
      await ctx.storage
          .bucket('bucket')
          .file(p.url.join('$_root/data', 'export_8.jsonl'))
          .exists(),
      isTrue,
    );
    bloc.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
