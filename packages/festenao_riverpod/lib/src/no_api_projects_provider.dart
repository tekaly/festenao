/// The projects of an app with **no backend**: no cloud function, no api, the
/// app talks to firestore directly and the no-api security rules (see
/// `festenao_dartff/festenao_firebase_no_api_context.dart/firestore.rules`)
/// are what allows or refuses each write.
///
/// | The app does | How, with no server |
/// | --- | --- |
/// | create a project | writes `app/<appId>/project/<id>` naming the signed in user as its `creatorUserId`, then its own admin access documents — which the rules allow *because* of that field |
/// | list its projects | reads its own access documents, [UserProjectsSdbSynchronizer] turns them into the local project list |
/// | keep that list across devices | the local projects database is itself synced to `app/<appId>/user_prv/<userId>/data/projects` |
/// | share a project | writes the access documents of another user as an admin, or opens the project data to anyone with the public access document |
///
/// Needs [festenaoFirebaseContextProvider], [festenaoAppFlavorContextProvider]
/// and [festenaoUserProjectsSdbManagerProvider] overridden (see
/// `festenaoFlutterProviderOverrides` and [festenaoFirebaseContextOverrides]).
library;

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:riverpod/riverpod.dart';

import 'app_flavor_context_provider.dart';
import 'firebase_context_provider.dart';
import 'user_projects_sdb_provider.dart';

/// The firestore projects of the app, `app/<appId>/project/<projectId>`.
///
/// Everything the app does to a project goes through this: creating it,
/// granting access to another user, and reading back what the signed in user
/// may do with it.
final festenaoProjectsFsProvider =
    Provider<TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>>((ref) {
      initFestenaoFsBuilders();
      return TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
        entityCollectionInfo: projectCollectionInfo,
        firestore: ref.watch(festenaoFirestoreProvider),
        rootDocument: fsAppRoot(
          ref.watch(festenaoAppFlavorContextProvider).appId,
        ),
      );
    }, name: 'festenaoProjectsFs');

/// The local projects database of the signed in user, null until there is one.
///
/// The manager behind it (see `festenaoUserProjectsSdbManagerOverride`) opens
/// a per user database synchronized to
/// `app/<appId>/user_prv/<userId>/data/projects`, which the no-api rules grant
/// to that user only.
final festenaoProjectsSdbProvider = Provider<UserProjectsSdb?>(
  (ref) => ref.watch(festenaoUserProjectsSdbProvider).value,
  name: 'festenaoProjectsSdb',
);

/// Rebuilds the local project list from the firestore access documents.
final festenaoProjectsSynchronizerProvider =
    Provider<UserProjectsSdbSynchronizer?>((ref) {
      var projectsSdb = ref.watch(festenaoProjectsSdbProvider);
      if (projectsSdb == null) {
        return null;
      }
      var synchronizer = UserProjectsSdbSynchronizer(
        projectsSdb: projectsSdb,
        fsProjects: ref.watch(festenaoProjectsFsProvider),
      );
      ref.onDispose(synchronizer.dispose);
      return synchronizer;
    }, name: 'festenaoProjectsSynchronizer');

/// Fills the local project list from firestore, once per signed in user.
///
/// It has to run before [festenaoUserProjectsProvider] yields anything: the
/// local database only streams the projects of a user it has been told is
/// ready, which is what `applyUserProjects` marks at the end. Invalidate this
/// provider to refresh the list ([FestenaoNoApiProjects.refresh] does).
final festenaoProjectsBootstrapProvider = FutureProvider<void>((ref) async {
  var userId = ref.watch(festenaoFirebaseUserIdProvider);
  var synchronizer = ref.watch(festenaoProjectsSynchronizerProvider);
  if (userId == null || synchronizer == null) {
    return;
  }
  await synchronizer.syncUserProjects(userId: userId);
}, name: 'festenaoProjectsBootstrap');

/// Makes sure [festenaoProjectsBootstrapProvider] runs, without depending on
/// its state: the local database only streams the projects of a user once
/// the bootstrap has marked it ready, so a list watched before the bootstrap
/// would wait forever. Errors stay on the bootstrap provider, where a screen
/// can show them and offer a retry.
void _ensureBootstrap(Ref ref) {
  ref.listen(festenaoProjectsBootstrapProvider, (previous, next) {});
}

/// The projects the signed in user has access to, empty while signed out.
///
/// Waits for the local list to be ready (see
/// [festenaoProjectsBootstrapProvider]): a list is never shown empty because
/// it has not been read yet.
final festenaoUserProjectsProvider = StreamProvider<List<SdbUserProject>>((
  ref,
) async* {
  var userId = ref.watch(festenaoFirebaseUserIdProvider);
  var projectsSdb = ref.watch(festenaoProjectsSdbProvider);
  if (userId == null || projectsSdb == null) {
    yield <SdbUserProject>[];
    return;
  }
  _ensureBootstrap(ref);
  yield* projectsSdb.onProjects(userId: userId);
}, name: 'festenaoUserProjects');

/// One project of the signed in user, null when it has no access to it.
final festenaoUserProjectProvider =
    StreamProvider.family<SdbUserProject?, String>((ref, projectId) async* {
      var userId = ref.watch(festenaoFirebaseUserIdProvider);
      var projectsSdb = ref.watch(festenaoProjectsSdbProvider);
      if (userId == null || projectsSdb == null) {
        yield null;
        return;
      }
      _ensureBootstrap(ref);
      yield* projectsSdb.onProject(projectId, userId: userId);
    }, name: 'festenaoUserProject');

/// The public access document of a project,
/// `access/project/entity_id/<projectId>/public_access/public`.
///
/// Readable by anyone, signed out included, so a viewer opening a shared link
/// can tell a project that is not (or no longer) public from one that failed
/// to load. `exists` is false (and `read` null) while the project is private.
///
/// A firestore without change tracking (the rest services, on desktop) has no
/// `onSnapshot`: the document is then read once, and read again by
/// [FestenaoNoApiProjects.setPublicAccess] and [FestenaoNoApiProjects.refresh].
final festenaoProjectPublicAccessProvider =
    StreamProvider.family<TkCmsFsPublicAccess, String>((ref, projectId) {
      var fsProjects = ref.watch(festenaoProjectsFsProvider);
      var firestore = fsProjects.firestore;
      var docRef = fsProjects.fsEntityPublicAccessRef(projectId);
      if (!firestore.service.supportsTrackChanges) {
        return Stream.fromFuture(docRef.get(firestore));
      }
      return docRef.onSnapshot(firestore);
    }, name: 'festenaoProjectPublicAccess');

/// What the signed in user may do with a project.
///
/// The access levels nest: `admin` implies `write`, `write` implies `read`.
extension FestenaoUserProjectAccessExt on SdbUserProject {
  /// True when the project (and its data) may be read.
  bool get canRead => TkCmsCvUserAccessCommonExt(this).isRead || canWrite;

  /// True when the project data may be written.
  bool get canWrite =>
      TkCmsCvUserAccessCommonExt(this).isWrite || isProjectAdmin;

  /// True when the project itself — its name, its access documents, its
  /// public access — may be written.
  bool get isProjectAdmin => TkCmsCvUserAccessCommonExt(this).isAdmin;

  /// The access level, for display.
  String get accessLabel => isProjectAdmin
      ? 'admin'
      : canWrite
      ? 'write'
      : canRead
      ? 'read'
      : 'none';
}

/// The project commands of a no-backend app, see
/// [festenaoNoApiProjectsProvider].
///
/// Every command runs as the signed in user and is checked by the firestore
/// rules: a command the user is not allowed to run fails with a permission
/// error rather than being hidden here.
class FestenaoNoApiProjects {
  final Ref _ref;

  /// The project commands of a no-backend app.
  FestenaoNoApiProjects(this._ref);

  /// The firestore projects.
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> get fsProjects =>
      _ref.read(festenaoProjectsFsProvider);

  /// The local projects database of the signed in user, null until there is
  /// one.
  UserProjectsSdb? get projectsSdb => _ref.read(festenaoProjectsSdbProvider);

  /// The signed in user id, read from the auth itself so that it does not
  /// depend on anyone watching [festenaoFirebaseUserProvider].
  Future<String> _userId() async {
    var user = await _ref
        .read(festenaoFirebaseAuthProvider)
        .onCurrentUser
        .first;
    var userId = user?.uid;
    if (userId == null) {
      throw StateError('Not signed in');
    }
    return userId;
  }

  /// Refreshes the local project list of the signed in user from firestore.
  Future<void> refresh() async {
    _ref.invalidate(festenaoProjectsBootstrapProvider);
    // The public access flags too, for a firestore without change tracking.
    _ref.invalidate(festenaoProjectPublicAccessProvider);
    await _ref.read(festenaoProjectsBootstrapProvider.future);
  }

  /// Refreshes one project of the local list from firestore (after a create
  /// or a rename, so the change shows right away).
  Future<void> syncOne(String projectId) async {
    var userId = await _userId();
    await _ref
        .read(festenaoProjectsSynchronizerProvider)
        ?.syncOne(userId: userId, projectId: projectId);
  }

  /// Creates a project owned by the signed in user, and returns its id.
  ///
  /// No backend: the project document is written straight to firestore,
  /// naming the signed in user as its `creatorUserId`. That field is the whole
  /// trick of the no-api rules — it is what lets the same user then create its
  /// own admin access documents, which every later read and write is checked
  /// against.
  Future<String> createProject({
    required String name,
    String? projectId,
  }) async {
    var userId = await _userId();
    var newProjectId = await fsProjects.standaloneCreateEntity(
      entity: FsProject()..name.v = name,
      userId: userId,
      entityId: projectId,
    );
    await _ref
        .read(festenaoProjectsSynchronizerProvider)
        ?.syncOne(userId: userId, projectId: newProjectId);
    return newProjectId;
  }

  /// Renames a project (admin access needed, the root document is admin only).
  Future<void> renameProject(String projectId, String name) async {
    var ref = fsProjects.fsEntityRef(projectId);
    var project = await ref.get(fsProjects.firestore);
    if (project.name.v != name) {
      project.name.v = name;
      await ref.set(fsProjects.firestore, project, SetOptions(merge: true));
    }
    await syncOne(projectId);
  }

  /// Grants [userId] [access] on [projectId], or revokes it when [access] is
  /// null.
  ///
  /// Signed in as an admin of the project, which is the only thing the rules
  /// let write the two access documents. The other user sees the project
  /// appear in (or disappear from) its own list on its next refresh.
  Future<void> setUserAccess({
    required String projectId,
    required String userId,
    TkCmsFsUserAccess? access,
  }) async {
    await fsProjects.standaloneSetUserAccess(
      entityId: projectId,
      userId: userId,
      access: access,
    );
  }

  /// Opens the project data to anyone when [read] is true, closes it
  /// otherwise (admin access needed).
  ///
  /// This is what sharing a project by url relies on: with public read, the
  /// `data` sub collections of the project — its synchronized databases — are
  /// readable without signing in. The project document itself stays private.
  Future<void> setPublicAccess({
    required String projectId,
    required bool read,
  }) async {
    await fsProjects.standaloneSetPublicAccess(
      entityId: projectId,
      access: read ? (TkCmsFsPublicAccess()..read.v = true) : null,
    );
    // Read back, for a firestore without change tracking.
    _ref.invalidate(festenaoProjectPublicAccessProvider(projectId));
  }

  /// Deletes a project and everything below it (admin access needed).
  ///
  /// The public access document goes first — the purge does not know about it
  /// and it must not outlive the project — then the project is flagged
  /// deleted and purged, the signed in user's own access documents last so it
  /// keeps the admin access the purge needs. The local list is updated right
  /// away.
  Future<void> deleteProject(String projectId) async {
    var userId = await _userId();
    await fsProjects.standaloneSetPublicAccess(
      entityId: projectId,
      access: null,
    );
    _ref.invalidate(festenaoProjectPublicAccessProvider(projectId));
    await fsProjects.standaloneDeleteAndPurge(
      entityId: projectId,
      userId: userId,
    );
    await projectsSdb?.deleteProject(projectId, userId: userId);
  }
}

/// The project commands of a no-backend app.
///
/// ```dart
/// var projectId = await ref
///     .read(festenaoNoApiProjectsProvider)
///     .createProject(name: 'My project');
/// ```
final festenaoNoApiProjectsProvider = Provider<FestenaoNoApiProjects>(
  FestenaoNoApiProjects.new,
  name: 'festenaoNoApiProjects',
);
