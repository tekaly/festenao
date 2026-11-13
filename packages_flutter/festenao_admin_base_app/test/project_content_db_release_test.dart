import 'dart:async';

import 'package:festenao_admin_base_app/admin_app/admin_app_context_db_bloc.dart';
import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen_bloc.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:festenao_common/data/src/festenao_synced_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tekaly_sembast_synced/synced_db_firestore.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_content.dart';
import 'package:tkcms_common/tkcms_firebase.dart';

const _timeout = Timeout(Duration(minutes: 2));

class _FakeSyncedDb implements SyncedDb {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeContentDb implements ContentDb {
  var synchronizeCount = 0;

  @override
  SyncedDb get syncedDb => _FakeSyncedDb();

  @override
  Future<SyncedSyncStat> synchronize() async {
    synchronizeCount++;
    return SyncedSyncStat();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGrabbedContentDb implements GrabbedContentDb {
  @override
  final ContentDb contentDb = _FakeContentDb();

  @override
  FestenaoSyncedDb get festenaoSyncedDb => throw UnimplementedError();
}

/// Counts the grabs and the releases; a grab waits for [grabGate] when set.
class _FakeProjectsDbBloc implements MultiProjectsDbBloc {
  var grabCount = 0;
  var releaseCount = 0;
  Completer<void>? grabGate;

  @override
  Future<GrabbedContentDb> grabContentDb({
    required String userId,
    required String projectId,
  }) async =>
      (await grabContentDbOrNull(userId: userId, projectId: projectId))!;

  @override
  Future<GrabbedContentDb?> grabContentDbOrNull({
    required String userId,
    required String projectId,
  }) async {
    grabCount++;
    await grabGate?.future;
    return _FakeGrabbedContentDb();
  }

  @override
  Future<void> releaseContentDb(GrabbedContentDb contentDb) async {
    releaseCount++;
  }
}

class _ProjectContext implements ByProjectIdAdminAppProjectContext {
  @override
  final String projectId;

  _ProjectContext(this.projectId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late String userId;

  setUpAll(() async {
    initDbProjectsBuilders();
    var ffContext = await initFirebaseServicesLocalMemory(
      projectId: 'content-db-release-test',
    ).init();
    var auth = ffContext.auth;
    globalProjectsDbOrNull = ProjectsDb(
      factory: newDatabaseFactoryMemory(),
      name: 'content_db_release_projects.db',
    );
    await globalProjectsDb.ready;
    globalTkCmsFbIdentityBloc = TkCmsFbIdentityBloc(auth: auth);
    await auth.signInOrUpWithEmailAndPassword(email: 'u1', password: 'u1');
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity != null,
    );
    userId = auth.currentUser!.uid;
  });

  test('project root sync releases the content db it grabs', () async {
    var projectsDbBloc = _FakeProjectsDbBloc();
    globalProjectsDbBloc = projectsDbBloc;
    await globalProjectsDb.addProject(
      DbProject()
        ..uid.v = 'p_sync'
        ..userId.v = userId
        ..name.v = 'Sync'
        ..admin.v = true,
    );
    var bloc = ProjectRootScreenBloc(projectId: 'p_sync');
    addTearDown(bloc.dispose);
    await bloc.state.firstWhere((state) => state.project != null);
    await bloc.sync();
    await bloc.sync();
    expect(projectsDbBloc.grabCount, 2);
    expect(projectsDbBloc.releaseCount, 2);
  }, timeout: _timeout);

  test('a context db bloc disposed during its grab releases it', () async {
    var projectsDbBloc = _FakeProjectsDbBloc()..grabGate = Completer<void>();
    globalProjectsDbBloc = projectsDbBloc;
    var dbBloc = AdminAppProjectContextDbBloc(
      projectContext: _ProjectContext('p_grab'),
    );
    var grab = dbBloc.grabSyncedDb();
    // Bounded: the grab reaches the projects db bloc.
    for (var i = 0; i < 50 && projectsDbBloc.grabCount == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(projectsDbBloc.grabCount, 1);
    // Disposed (screen closed) before the content db is ready.
    dbBloc.selfDispose();
    projectsDbBloc.grabGate!.complete();
    await grab;
    for (var i = 0; i < 50 && projectsDbBloc.releaseCount == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(projectsDbBloc.releaseCount, 1);
  }, timeout: _timeout);
}
