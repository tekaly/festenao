import 'package:festenao_common/admin/festenao_apps_admin.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  late Firestore firestore;
  late FestenaoAppsAdmin admin;
  setUp(() {
    firestore = newFirestoreMemory();
    admin = FestenaoAppsAdmin(firestore: firestore);
  });

  group('FestenaoUserAccessGrant', () {
    test('toUserAccess', () {
      var access = FestenaoUserAccessGrant.read.toUserAccess();
      expect(
        [access.isRead, access.isWrite, access.isAdmin],
        [true, false, false],
      );
      access = FestenaoUserAccessGrant.superAdmin.toUserAccess();
      expect(
        [access.isRead, access.isWrite, access.isAdmin],
        [true, true, true],
      );
      expect(access.role.v, roleSuperAdmin);
    });

    test('applyTo resets the rights', () {
      var access = FestenaoUserAccessGrant.superAdmin.toUserAccess();
      FestenaoUserAccessGrant.write.applyTo(access);
      expect(
        [access.isRead, access.isWrite, access.isAdmin],
        [true, true, false],
      );
      expect(access.role.v, isNull);
    });

    test('of', () {
      for (var grant in FestenaoUserAccessGrant.values) {
        expect(FestenaoUserAccessGrant.of(grant.toUserAccess()), grant);
      }
      expect(FestenaoUserAccessGrant.of(TkCmsFsUserAccess()), isNull);
    });
  });

  test('apps', () async {
    await admin.appAccess
        .fsEntityRef('app2')
        .set(firestore, TkCmsFsApp()..name.v = 'App 2');
    var apps = await admin.apps();
    expect(apps.map((app) => app.appId), ['app2']);
    expect(apps.first.name, 'App 2');

    // The missing documents, when the backend lists them.
    admin = FestenaoAppsAdmin(
      firestore: firestore,
      listDocumentIds: (path) async => switch (path) {
        'app' => ['app1', 'app2'],
        'access/app/entity_id' => ['app3'],
        _ => <String>[],
      },
    );
    apps = await admin.apps();
    expect(apps.map((app) => app.appId), ['app1', 'app2', 'app3']);
    expect(apps.map((app) => app.exists), [false, true, false]);
  });

  test('app user access, both sides', () async {
    await admin.setUserAccess(
      admin.appAccess,
      'app1',
      'u1',
      grant: FestenaoUserAccessGrant.superAdmin,
      name: 'User 1',
      email: 'u1@example.com',
    );
    // Where the server checks an app admin.
    var entitySide = await admin.appAccess
        .fsEntityUserAccessRef('app1', 'u1')
        .get(firestore);
    expect(entitySide.isAdmin, isTrue);
    expect(entitySide.hasSuperAdminRole, isTrue);
    expect(
      (await firestore.doc('access/app/entity_id/app1/user_access/u1').get())
          .exists,
      isTrue,
    );
    var userSide = await admin.appAccess
        .fsUserEntityAccessRef('u1', 'app1')
        .get(firestore);
    expect(userSide.hasSuperAdminRole, isTrue);

    var accesses = await admin.userAccesses(admin.appAccess, 'app1');
    expect(accesses.map(festenaoAdminUserAccessLabel), ['User 1']);
    expect(accesses.first.email.v, 'u1@example.com');

    // Made a reader: no longer a super admin, the name kept.
    await admin.setUserAccess(
      admin.appAccess,
      'app1',
      'u1',
      grant: FestenaoUserAccessGrant.read,
    );
    accesses = await admin.userAccesses(admin.appAccess, 'app1');
    expect(
      FestenaoUserAccessGrant.of(accesses.first),
      FestenaoUserAccessGrant.read,
    );
    expect(accesses.first.hasSuperAdminRole, isFalse);
    expect(accesses.first.name.v, 'User 1');

    await admin.setUserAccess(admin.appAccess, 'app1', 'u1', grant: null);
    expect(await admin.userAccesses(admin.appAccess, 'app1'), isEmpty);
    expect(
      (await admin.appAccess.fsUserEntityAccessRef('u1', 'app1').get(firestore))
          .exists,
      isFalse,
    );
  });

  test('projects and the accesses of a user', () async {
    var projectAccess = admin.projectAccess('app1');
    await projectAccess
        .fsEntityRef('p1')
        .set(firestore, FsProject()..name.v = 'Project 1');
    var projects = await admin.projects('app1');
    expect(projects.map((project) => project.name), ['Project 1']);
    expect(projectAccess.fsEntityRef('p1').path, 'app/app1/project/p1');

    await admin.appAccess.fsEntityRef('app1').set(firestore, TkCmsFsApp());
    await admin.setUserAccess(
      admin.appAccess,
      'app1',
      'u1',
      grant: FestenaoUserAccessGrant.admin,
    );
    await admin.setUserAccess(
      projectAccess,
      'p1',
      'u1',
      grant: FestenaoUserAccessGrant.write,
    );
    var accesses = await admin.userEntityAccesses('u1');
    expect(accesses.map((access) => '${access.appId}/${access.projectId}'), [
      'app1/null',
      'app1/p1',
    ]);
    expect(
      accesses.map((access) => FestenaoUserAccessGrant.of(access.access)),
      [FestenaoUserAccessGrant.admin, FestenaoUserAccessGrant.write],
    );
  });
}
