import 'package:festenao_common/festenao_firebase.dart' show FirebaseContext;
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firebase_service_account.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

/// How an admin build reaches a firebase project with a service account.
///
/// [festenaoAdminFirebaseRest] works everywhere (the web included); the admin
/// sdk one (`festenaoAdminFirebaseAdminSdk` of `firebase_admin_sdk.dart`, io
/// only) also lists the documents that do not exist.
abstract class FestenaoAdminFirebase {
  /// What the user is told it goes through: `rest apis`, `admin sdk`.
  String get name;

  /// Firestore, auth (an admin) and storage, as the service account
  /// [serviceAccountMap].
  Future<FirebaseContext> initWithServiceAccount(Map serviceAccountMap);

  /// The ids of the documents of [collectionPath], the ones that do not exist
  /// but hold sub collections included; null when [firestore] cannot list
  /// them (a query only returns the existing ones).
  Future<List<String>?> listDocumentIds(
    Firestore firestore,
    String collectionPath,
  );
}

class _FestenaoAdminFirebaseRest implements FestenaoAdminFirebase {
  @override
  String get name => 'rest apis';

  @override
  Future<FirebaseContext> initWithServiceAccount(Map serviceAccountMap) =>
      festenaoInitFirebaseWithServiceAccount(
        serviceAccountMap: serviceAccountMap,
      );

  @override
  Future<List<String>?> listDocumentIds(
    Firestore firestore,
    String collectionPath,
  ) async => null;
}

/// The rest apis: web compatible, the missing documents are not listed.
final FestenaoAdminFirebase festenaoAdminFirebaseRest =
    _FestenaoAdminFirebaseRest();

/// The access to grant on an entity (an app, a project).
enum FestenaoUserAccessGrant {
  /// Read only.
  read,

  /// Read and write.
  write,

  /// Read, write and admin.
  admin,

  /// Admin plus the super admin role.
  superAdmin;

  /// The matching entity user access.
  TkCmsFsUserAccess toUserAccess() {
    var userAccess = TkCmsFsUserAccess();
    applyTo(userAccess);
    return userAccess;
  }

  /// Sets the rights of [userAccess] to this grant only, whatever they were
  /// (a super admin made a reader loses the role), the other fields kept.
  void applyTo(TkCmsCvUserAccessCommon userAccess) {
    userAccess
      ..read.v = null
      ..write.v = null
      ..admin.v = null
      ..role.v = null;
    switch (this) {
      case FestenaoUserAccessGrant.read:
        userAccess.read.v = true;
      case FestenaoUserAccessGrant.write:
        userAccess.write.v = true;
      case FestenaoUserAccessGrant.admin:
        userAccess.grantAdminAccess();
      case FestenaoUserAccessGrant.superAdmin:
        userAccess.grantSuperAdminAccess();
    }
    userAccess.fixAccess();
  }

  /// What the user reads: `read`, `write`, `admin`, `super admin`.
  String get label => switch (this) {
    FestenaoUserAccessGrant.read => 'read',
    FestenaoUserAccessGrant.write => 'write',
    FestenaoUserAccessGrant.admin => 'admin',
    FestenaoUserAccessGrant.superAdmin => 'super admin',
  };

  /// The grant [userAccess] amounts to, null when it gives no right.
  static FestenaoUserAccessGrant? of(TkCmsCvUserAccessCommon userAccess) {
    if (userAccess.isAdmin) {
      return userAccess.hasSuperAdminRole
          ? FestenaoUserAccessGrant.superAdmin
          : FestenaoUserAccessGrant.admin;
    }
    if (userAccess.isWrite) {
      return FestenaoUserAccessGrant.write;
    }
    if (userAccess.isRead) {
      return FestenaoUserAccessGrant.read;
    }
    return null;
  }
}

/// One app of the firebase project (`app/<appId>`), existing or not.
class FestenaoAdminApp {
  /// The app id.
  final String appId;

  /// The app document, null when it does not exist (the id is only known
  /// because something hangs below it).
  final TkCmsFsApp? app;

  /// One app.
  FestenaoAdminApp({required this.appId, this.app});

  /// Whether the app document exists.
  bool get exists => app != null;

  /// Its name, when it has one.
  String? get name => app?.name.v;
}

/// One project of an app (`app/<appId>/project/<projectId>`), existing or
/// not.
class FestenaoAdminProject {
  /// The project id.
  final String projectId;

  /// The project document, null when it does not exist.
  final FsProject? project;

  /// One project.
  FestenaoAdminProject({required this.projectId, this.project});

  /// Whether the project document exists.
  bool get exists => project != null;

  /// Its name, when it has one.
  String? get name => project?.name.v;
}

/// One access a user has, as seen from the user (the entity being an app or
/// a project of [appId]).
class FestenaoAdminUserEntityAccess {
  /// The app.
  final String appId;

  /// The project, null for the access to the app itself.
  final String? projectId;

  /// The access, as written on the user side.
  final TkCmsEditedFsUserAccess access;

  /// One access of a user.
  FestenaoAdminUserEntityAccess({
    required this.appId,
    this.projectId,
    required this.access,
  });

  /// The entity: the project when there is one, the app otherwise.
  String get entityId => projectId ?? appId;
}

/// The apps of a firebase project and who may do what on them, for an admin
/// build holding a service account: it reads and writes the access documents
/// directly.
///
/// The access are the tkcms entity ones, the ones the server and the apps
/// check:
///
/// - app: `access/app/entity_id/<appId>/user_access/<userId>` (and the user
///   side `access/app/user_id/<userId>/entity_access/<appId>`), where an app
///   admin or super admin is made;
/// - project: the same below `app/<appId>`.
///
/// Both sides are always written together ([setUserAccess]).
class FestenaoAppsAdmin {
  /// The firestore of the project, written with admin rights.
  final Firestore firestore;

  /// Lists the document ids of a collection, the missing documents included
  /// (see [FestenaoAdminFirebase.listDocumentIds]); without it, an app or a
  /// project whose document was never written is not listed.
  final Future<List<String>?> Function(String collectionPath)? listDocumentIds;

  /// The apps of [firestore].
  FestenaoAppsAdmin({required this.firestore, this.listDocumentIds}) {
    initFestenaoFsBuilders();
    cvAddConstructor(TkCmsEditedFsUserAccess.new);
  }

  /// The app entities and their access, at the top of the database.
  late final appAccess = TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
    entityCollectionInfo: tkCmsFsAppCollectionInfo,
    firestore: firestore,
  );

  /// The project entities of [appId] and their access, below `app/<appId>`.
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> projectAccess(
    String appId,
  ) => TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
    entityCollectionInfo: projectCollectionInfo,
    firestore: firestore,
    rootDocument: fsAppRoot(appId),
  );

  Future<List<String>> _listIds(String collectionPath) async =>
      await listDocumentIds?.call(collectionPath) ?? const <String>[];

  /// Every app: the `app` documents, plus (when [listDocumentIds] can) the
  /// ids that only hold sub collections or access, by id.
  Future<List<FestenaoAdminApp>> apps() async {
    var docs = await appAccess.fsEntityCollectionRef.get(firestore);
    var byId = <String, FestenaoAdminApp>{
      for (var doc in docs) doc.id: FestenaoAdminApp(appId: doc.id, app: doc),
    };
    // The apps having access documents, `access/app/entity_id/<appId>`.
    var accessPath = appAccess.getRootPath(
      '$tkCmsFsEntityTypeAccessCollectionId/${appAccess.collectionId}/'
      '$tkCmsFsEntityIdCollectionId',
    );
    for (var path in [appAccess.fsEntityCollectionRef.path, accessPath]) {
      for (var id in await _listIds(path)) {
        byId.putIfAbsent(id, () => FestenaoAdminApp(appId: id));
      }
    }
    return byId.values.toList()..sort((a, b) => a.appId.compareTo(b.appId));
  }

  /// The projects of [appId], the missing documents included when
  /// [listDocumentIds] can, by id.
  Future<List<FestenaoAdminProject>> projects(String appId) async {
    var access = projectAccess(appId);
    var docs = await access.fsEntityCollectionRef.get(firestore);
    var byId = <String, FestenaoAdminProject>{
      for (var doc in docs)
        doc.id: FestenaoAdminProject(projectId: doc.id, project: doc),
    };
    for (var id in await _listIds(access.fsEntityCollectionRef.path)) {
      byId.putIfAbsent(id, () => FestenaoAdminProject(projectId: id));
    }
    return byId.values.toList()
      ..sort((a, b) => a.projectId.compareTo(b.projectId));
  }

  /// The users having an access on [entityId] of [entityAccess], by name.
  Future<List<TkCmsEditedFsUserAccess>> userAccesses(
    TkCmsFirestoreDatabaseServiceEntityAccess entityAccess,
    String entityId,
  ) async {
    var list = await entityAccess
        .fsEntityUserAccessCollectionRef(entityId)
        .cast<TkCmsEditedFsUserAccess>()
        .get(firestore);
    // A copy: the admin sdk answers a read only list.
    return [...list]..sort(
      (a, b) => festenaoAdminUserAccessLabel(
        a,
      ).compareTo(festenaoAdminUserAccessLabel(b)),
    );
  }

  /// Gives [userId] the access [grant] on [entityId] of [entityAccess], or
  /// removes it when [grant] is null, on both sides.
  ///
  /// The other fields of an existing access are kept; [name] and [email]
  /// (informative, for whoever reads the list) are set when given.
  Future<void> setUserAccess(
    TkCmsFirestoreDatabaseServiceEntityAccess entityAccess,
    String entityId,
    String userId, {
    required FestenaoUserAccessGrant? grant,
    String? name,
    String? email,
  }) async {
    if (grant == null) {
      await entityAccess.setEntityUserAccess(
        entityId: entityId,
        userId: userId,
        userAccess: null,
      );
      return;
    }
    var access = await entityAccess
        .fsEntityUserAccessRef(entityId, userId)
        .cast<TkCmsEditedFsUserAccess>()
        .get(firestore);
    grant.applyTo(access);
    if (name != null) {
      access.name.v = name;
    }
    if (email != null) {
      access.email.v = email;
    }
    await entityAccess.setEntityUserAccess(
      entityId: entityId,
      userId: userId,
      userAccess: access,
    );
  }

  /// Every access of [userId]: to the apps, then to the projects of each app
  /// in [appIds] (all the [apps] by default).
  Future<List<FestenaoAdminUserEntityAccess>> userEntityAccesses(
    String userId, {
    List<String>? appIds,
  }) async {
    var result = <FestenaoAdminUserEntityAccess>[];
    var appAccesses = await appAccess
        .fsUserEntityAccessCollectionRef(userId)
        .cast<TkCmsEditedFsUserAccess>()
        .get(firestore);
    for (var access in appAccesses) {
      result.add(
        FestenaoAdminUserEntityAccess(appId: access.id, access: access),
      );
    }
    appIds ??= (await apps()).map((app) => app.appId).toList();
    for (var appId in appIds) {
      var projectAccesses = await projectAccess(appId)
          .fsUserEntityAccessCollectionRef(userId)
          .cast<TkCmsEditedFsUserAccess>()
          .get(firestore);
      for (var access in projectAccesses) {
        result.add(
          FestenaoAdminUserEntityAccess(
            appId: appId,
            projectId: access.id,
            access: access,
          ),
        );
      }
    }
    return result;
  }
}

/// What a user access is listed as: its name, its email, or the user id.
String festenaoAdminUserAccessLabel(TkCmsEditedFsUserAccess access) {
  for (var value in [access.name.v, access.email.v]) {
    if (value != null && value.isNotEmpty) {
      return value;
    }
  }
  return access.id;
}
