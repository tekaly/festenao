/// The no-backend project flow, on an in-memory firebase: sign in, create a
/// project, rename it, open it to the public, share it with another user,
/// delete it.
///
/// The rules are not enforced by the local firebase; what is checked here is
/// the shape of what the app writes and reads back, which is what the rules
/// project (`festenao_firebase_no_api_context.dart`) tests against the
/// emulator.
library;

import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/misc.dart' show ProviderListenable;
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

final _appFlavorContext = FestenaoAppFlavorContext(
  packageName: 'com.tekaly.festenao_riverpod.test',
  appFlavorContext: FlavorContext.test.toAppFlavorContext(
    baseAppId: 'festenao_riverpod_no_api',
  ),
);

void main() {
  late FirebaseContext firebaseContext;
  late ProviderContainer container;

  setUp(() async {
    var sdbFactory = newSdbFactoryMemory();
    firebaseContext = await initFirebaseServicesLocalSdb(
      sdbFactory: newSdbFactoryMemory(),
      projectId: 'festenao-riverpod-no-api-test',
    ).init();
    container = ProviderContainer(
      overrides: [
        festenaoAppFlavorContextProvider.overrideWithValue(_appFlavorContext),
        festenaoSdbFactoryProvider.overrideWithValue(sdbFactory),
        festenaoUserProjectsSdbManagerOverride(
          factory: sdbFactory,
          app: _appFlavorContext.appId,
        ),
        ...festenaoFirebaseContextOverrides(firebaseContext),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await firebaseContext.close();
    });
  });

  /// Keeps [provider] alive and started for the rest of the test.
  void listen(ProviderListenable<Object?> provider) {
    container.listen(provider, (previous, next) {});
  }

  /// Signs [email] in and returns its user id, once the whole container
  /// agrees on it: the auth stream, and the per user projects database the
  /// manager switches to behind it.
  Future<String> signIn(String email) async {
    listen(festenaoFirebaseUserProvider);
    listen(festenaoUserProjectsSdbProvider);
    var credential = await container
        .read(festenaoFirebaseAuthProvider)
        .signInOrUpWithEmailAndPassword(email: email, password: 'test1234');
    var userId = credential.user.uid;
    for (var i = 0; i < 500; i++) {
      if (container.read(festenaoFirebaseUserIdProvider) == userId &&
          container.read(festenaoUserProjectsSdbProvider).value?.userId ==
              userId) {
        return userId;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('$email did not become the current user');
  }

  /// The project list of the signed in user, refreshed from firestore and
  /// read from the local database in one shot.
  Future<List<SdbUserProject>> projects() async {
    await container.read(festenaoNoApiProjectsProvider).refresh();
    var projectsSdb = container.read(festenaoProjectsSdbProvider)!;
    return await projectsSdb.getProjects(userId: projectsSdb.userId!);
  }

  /// The streamed project list, once it satisfies [until].
  Future<List<SdbUserProject>> waitForProjects(
    bool Function(List<SdbUserProject> projects) until,
  ) async {
    listen(festenaoUserProjectsProvider);
    for (var i = 0; i < 500; i++) {
      var projects = container.read(festenaoUserProjectsProvider).value;
      if (projects != null && until(projects)) {
        return projects;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('projects never satisfied the condition');
  }

  test('create, rename, publish and delete a project', () async {
    var userId = await signIn('admin@festenao-riverpod-test.local');
    var commands = container.read(festenaoNoApiProjectsProvider);
    var fsProjects = container.read(festenaoProjectsFsProvider);

    // No backend: the project document and its access documents are written
    // by the app itself, on the strength of its `creatorUserId`.
    var projectId = await commands.createProject(name: 'Test');
    var fsProject = await fsProjects
        .fsEntityRef(projectId)
        .get(fsProjects.firestore);
    expect(fsProject.name.v, 'Test');
    expect(fsProject.creatorUserId.v, userId);
    var access = await fsProjects
        .fsUserEntityAccessRef(userId, projectId)
        .get(fsProjects.firestore);
    expect(access.admin.v, isTrue);

    // Mirrored in the local list right away, as its admin — and streamed by
    // the provider, which starts the bootstrap on its own.
    var project = (await waitForProjects(
      (projects) => projects.any((project) => project.fsId == projectId),
    )).singleWhere((project) => project.fsId == projectId);
    expect(project.name.v, 'Test');
    expect(project.isProjectAdmin, isTrue);
    expect(project.canWrite, isTrue);
    expect(project.canRead, isTrue);
    expect(project.accessLabel, 'admin');

    await commands.renameProject(projectId, 'Renamed');
    project = (await waitForProjects(
      (projects) => projects.any((project) => project.name.v == 'Renamed'),
    )).singleWhere((project) => project.fsId == projectId);
    expect(project.name.v, 'Renamed');
    listen(festenaoUserProjectProvider(projectId));
    expect(
      (await container.read(
        festenaoUserProjectProvider(projectId).future,
      ))?.name.v,
      'Renamed',
    );

    // Private by default.
    listen(festenaoProjectPublicAccessProvider(projectId));
    var publicAccess = await container.read(
      festenaoProjectPublicAccessProvider(projectId).future,
    );
    expect(publicAccess.exists, isFalse);

    await commands.setPublicAccess(projectId: projectId, read: true);
    publicAccess = await fsProjects
        .fsEntityPublicAccessRef(projectId)
        .get(fsProjects.firestore);
    expect(publicAccess.read.v, isTrue);

    await commands.setPublicAccess(projectId: projectId, read: false);
    publicAccess = await fsProjects
        .fsEntityPublicAccessRef(projectId)
        .get(fsProjects.firestore);
    expect(publicAccess.exists, isFalse);

    await commands.setPublicAccess(projectId: projectId, read: true);
    await commands.deleteProject(projectId);
    expect(
      (await fsProjects.fsEntityRef(projectId).get(fsProjects.firestore))
          .exists,
      isFalse,
    );
    expect(
      (await fsProjects
              .fsEntityPublicAccessRef(projectId)
              .get(fsProjects.firestore))
          .exists,
      isFalse,
    );
    expect(
      (await fsProjects
              .fsUserEntityAccessRef(userId, projectId)
              .get(fsProjects.firestore))
          .exists,
      isFalse,
    );
    expect(
      (await projects()).where((project) => project.fsId == projectId),
      isEmpty,
    );
    await waitForProjects(
      (projects) => !projects.any((project) => project.fsId == projectId),
    );
  });

  test('a user given read access sees the project, read only', () async {
    var guestId = await signIn('guest@festenao-riverpod-test.local');
    var ownerId = await signIn('owner@festenao-riverpod-test.local');
    var commands = container.read(festenaoNoApiProjectsProvider);
    var projectId = await commands.createProject(name: 'Shared');
    await commands.setUserAccess(
      projectId: projectId,
      userId: guestId,
      access: TkCmsFsUserAccess()
        ..read.v = true
        ..fixAccess(),
    );

    expect(await signIn('guest@festenao-riverpod-test.local'), guestId);
    var project = (await projects()).singleWhere(
      (project) => project.fsId == projectId,
    );
    expect(project.name.v, 'Shared');
    expect(project.canRead, isTrue);
    expect(project.canWrite, isFalse);
    expect(project.isProjectAdmin, isFalse);
    expect(project.accessLabel, 'read');

    // Revoked: gone from the guest list on the next refresh.
    expect(await signIn('owner@festenao-riverpod-test.local'), ownerId);
    await commands.setUserAccess(
      projectId: projectId,
      userId: guestId,
      access: null,
    );
    await signIn('guest@festenao-riverpod-test.local');
    expect(
      (await projects()).where((project) => project.fsId == projectId),
      isEmpty,
    );

    // The owner still has it.
    await signIn('owner@festenao-riverpod-test.local');
    expect(
      (await projects()).map((project) => project.fsId),
      contains(projectId),
    );
  });
}
