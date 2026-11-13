import 'dart:async';

import 'package:festenao_admin_base_app/screen/project_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_view_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/projects_screen_bloc.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

const _timeout = Timeout(Duration(minutes: 2));

/// The local projects of [userId].
Future<List<DbProject>> _localProjects(String userId) => globalProjectsDb
    .getProjectsQuery(userId: userId)
    .getRecords(globalProjectsDb.db);

/// Waits (bounded, about 2s) for [condition].
Future<bool> _waitFor(FutureOr<bool> Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (await condition()) {
      return true;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return false;
}

void main() {
  late FirebaseAuth auth;
  late FestenaoFirestoreDatabase fsDatabase;
  late String userId;

  Future<void> signIn() async {
    await auth.signInOrUpWithEmailAndPassword(email: 'u1', password: 'u1');
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity != null,
    );
  }

  Future<void> signOut() async {
    await auth.signOut();
    await globalTkCmsFbIdentityBloc.state.firstWhere(
      (state) => state.identity == null,
    );
  }

  setUpAll(() async {
    initTkCmsFsUserAccessBuilders();
    initDbProjectsBuilders();
    var ffContext = await initFirebaseServicesLocalMemory(
      projectId: 'project-access-sync-test',
    ).init();
    auth = ffContext.auth;
    fsDatabase = FestenaoFirestoreDatabase(
      firebaseContext: ffContext,
      flavorContext: AppFlavorContext.test,
    );
    globalFestenaoFirestoreDatabaseOrNull = fsDatabase;
    globalProjectsDbOrNull = ProjectsDb(
      factory: newDatabaseFactoryMemory(),
      name: 'project_access_sync_projects.db',
    );
    await globalProjectsDb.ready;
    globalTkCmsFbIdentityBloc = TkCmsFbIdentityBloc(auth: auth);
    await signIn();
    userId = auth.currentUser!.uid;
  });

  test('a created project has its creator as admin', () async {
    var bloc = ProjectEditScreenBloc();
    addTearDown(bloc.dispose);
    await bloc.state.first;
    await bloc.saveProject(DbProject()..name.v = 'Created');
    var created = (await _localProjects(userId))
        .singleWhere((project) => project.name.v == 'Created');
    expect(created.isAdmin, isTrue);
    var access = await fsDatabase.projectDb
        .fsUserEntityAccessRef(userId, created.fsId)
        .get(fsDatabase.firestore);
    expect(access.exists, isTrue);
    expect(access.isAdmin, isTrue);
  }, timeout: _timeout);

  test('a deleted project is not listed locally', () async {
    // Soft deleted: the accesses stay.
    var projectId = await fsDatabase.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Deleted one',
    );
    await fsDatabase.projectDb.deleteEntity(projectId, userId: userId);
    // And a live one, to know when the sync is done.
    var liveId = await fsDatabase.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Live one',
    );
    var bloc = ProjectsScreenBloc();
    addTearDown(bloc.dispose);
    var synced = await _waitFor(
      () async => (await _localProjects(userId)).any((p) => p.uid.v == liveId),
    );
    expect(synced, isTrue);
    expect(
      (await _localProjects(userId)).where((p) => p.uid.v == projectId),
      isEmpty,
    );
  }, timeout: _timeout);

  test('a revoked admin is no longer admin locally', () async {
    var projectId = await fsDatabase.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Revoked',
    );
    var bloc = ProjectsScreenBloc();
    addTearDown(bloc.dispose);
    Future<DbProject?> local() async =>
        (await _localProjects(userId))
            .where((p) => p.uid.v == projectId)
            .firstOrNull;
    expect(
      await _waitFor(() async => (await local())?.isAdmin ?? false),
      isTrue,
    );
    // Now a reader, the access written without the admin and role keys.
    await fsDatabase.projectDb
        .fsUserEntityAccessRef(userId, projectId)
        .set(fsDatabase.firestore, TkCmsFsUserAccess()..read.v = true);
    expect(
      await _waitFor(() async => (await local())?.isAdmin == false),
      isTrue,
    );
    expect((await local())!.isRead, isTrue);
  }, timeout: _timeout);

  test('project view stays on the local project once synced', () async {
    var projectId = await fsDatabase.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Not local yet',
    );
    var bloc = ProjectViewScreenBloc(projectId: projectId);
    addTearDown(bloc.dispose);
    var states = <ProjectViewScreenBlocState>[];
    var subscription = bloc.state.listen(states.add);
    addTearDown(subscription.cancel);
    await bloc.state.firstWhere((state) => state.fsProject != null);
    await globalProjectsDb.addProject(
      DbProject()
        ..uid.v = projectId
        ..userId.v = userId
        ..name.v = 'Not local yet'
        ..admin.v = true,
    );
    await bloc.state.firstWhere((state) => state.project != null);
    var localIndex = states.lastIndexWhere((state) => state.project != null);
    // A change of the firestore project.
    await fsDatabase.projectDb
        .fsEntityRef(projectId)
        .set(fsDatabase.firestore, FsProject()..name.v = 'Renamed');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(
      states.sublist(localIndex).where((state) => state.project == null),
      isEmpty,
    );
  }, timeout: _timeout);

  // Last: it signs out and in again.
  test('project root after sign out and in again', () async {
    var projectId = await fsDatabase.projectDb.createEntity(
      userId: userId,
      entity: FsProject()..name.v = 'Root',
    );
    await globalProjectsDb.addProject(
      DbProject()
        ..uid.v = projectId
        ..userId.v = userId
        ..name.v = 'Root'
        ..admin.v = true,
    );
    var bloc = ProjectRootScreenBloc(projectId: projectId);
    addTearDown(bloc.dispose);
    await bloc.state.firstWhere((state) => state.project != null);
    await signOut();
    await bloc.state.firstWhere((state) => state.identity == null);
    await signIn();
    expect(await _waitFor(() => bloc.state.value.project != null), isTrue);
    expect(bloc.state.value.identity, isNotNull);
  }, timeout: _timeout);
}
