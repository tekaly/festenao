import 'dart:convert';
import 'dart:io';

import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_support/festenao_firebase_admin_sdk.dart';
import 'package:path/path.dart';
import 'package:tekartik_firebase_admin_sdk/firestore_admin_sdk.dart';
import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_auth/auth_admin.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The firebase project id a firebase folder deploys to, i.e. the `default`
/// project of its `.firebaserc`.
///
/// [path] defaults to the current directory. Throws a [StateError] when the
/// folder is not a firebase folder (no `firebase.json`) or when no default
/// project is set — running an admin tool against the wrong project is worse
/// than not running it.
String firebaseFolderProjectId({String? path}) {
  var folder = normalize(absolute(path ?? '.'));
  if (!File(join(folder, 'firebase.json')).existsSync()) {
    throw StateError('no firebase.json in $folder');
  }
  var firebaseRcFile = File(join(folder, '.firebaserc'));
  if (!firebaseRcFile.existsSync()) {
    throw StateError('no .firebaserc in $folder');
  }
  var map = jsonDecode(firebaseRcFile.readAsStringSync()) as Map;
  var projectId = ((map['projects'] as Map?)?['default'])?.toString();
  if (projectId == null || projectId.isEmpty) {
    throw StateError('no default project in ${firebaseRcFile.path}');
  }
  return projectId;
}

/// A festenao app (`app/<appId>`) and its projects
/// (`app/<appId>/project/<projectId>`) in a firebase project, reached through
/// the admin sdk.
///
/// Named after the festenao app and project, not the firebase one: the
/// firebase project is [firebaseProjectId] and is fixed for a whole tool run,
/// while [appId] and the project id select what inside it is acted on.
///
/// It resolves the two things a dev tool constantly needs and that no app
/// should ever do: reading and creating the auth users, and writing the access
/// documents directly, bypassing the firestore rules.
///
/// Three levels, matching the three menus:
///
/// - global — the auth users of the firebase project;
/// - app — `app/<appId>/user_access/<userId>`, where an app admin is granted;
/// - app project — `app/<appId>/project/<projectId>` and its per user access.
class FestenaoFbAppProject {
  /// The firebase project id, fixed for the whole run.
  ///
  /// Informative: the credentials decide which project is really reached, this
  /// is what the tool reports and what it was asked to work on.
  final String? firebaseProjectId;

  /// The festenao app id, i.e. the `app/<appId>` document the projects and the
  /// app wide user access hang from — `festenao_dev`, `festenao_prod`, …
  ///
  /// Null until one is selected: the global level works without it.
  String? appId;

  /// Builds the firebase context on first use.
  final Future<FirebaseContext> Function() contextBuilder;

  /// Creates a project whose firebase context is built by [contextBuilder] on
  /// first use — lazily, so declaring a menu costs no network call.
  FestenaoFbAppProject({
    this.appId,
    this.firebaseProjectId,
    required this.contextBuilder,
  });

  /// The app of a firebase folder (the `default` project of its `.firebaserc`),
  /// reached with the ambient credentials
  /// (`gcloud auth application-default login`).
  factory FestenaoFbAppProject.firebaseFolder({
    String? path,
    String? appId,
    String? storageBucket,
  }) {
    var firebaseProjectId = firebaseFolderProjectId(path: path);
    return FestenaoFbAppProject.firebaseProjectId(
      firebaseProjectId: firebaseProjectId,
      appId: appId,
      storageBucket: storageBucket,
    );
  }

  /// A firebase project reached with the ambient credentials
  /// (`gcloud auth application-default login`).
  factory FestenaoFbAppProject.firebaseProjectId({
    required String firebaseProjectId,
    String? appId,
    String? storageBucket,
  }) {
    return FestenaoFbAppProject(
      appId: appId,
      firebaseProjectId: firebaseProjectId,
      contextBuilder: () => festenaoInitFirebaseAdminSdk(
        projectId: firebaseProjectId,
        storageBucket: storageBucket,
      ),
    );
  }

  /// A firebase project reached through the admin sdk with a service account
  /// map (the parsed content of a service account json).
  factory FestenaoFbAppProject.serviceAccountMap({
    required Map serviceAccountMap,
    String? appId,
    String? firebaseProjectId,
    String? storageBucket,
  }) {
    return FestenaoFbAppProject(
      appId: appId,
      firebaseProjectId:
          firebaseProjectId ?? serviceAccountMap['project_id']?.toString(),
      contextBuilder: () => festenaoInitFirebaseAdminSdkWithServiceAccount(
        serviceAccountMap: serviceAccountMap,
        options: storageBucket == null
            ? null
            : FirebaseAppOptions(storageBucket: storageBucket),
      ),
    );
  }

  /// On top of an already initialised [context], whichever firebase
  /// implementation built it.
  ///
  /// Listing or creating the auth users needs an auth service that can, which
  /// in practice means the admin sdk.
  factory FestenaoFbAppProject.context({
    required FirebaseContext context,
    String? appId,
    String? firebaseProjectId,
  }) {
    return FestenaoFbAppProject(
      appId: appId,
      firebaseProjectId:
          firebaseProjectId ?? context.firebaseApp.options.projectId,
      contextBuilder: () async => context,
    );
  }

  FirebaseContext? _context;

  /// The firebase context, built on first use and kept afterwards.
  Future<FirebaseContext> get context async =>
      _context ??= await contextBuilder();

  /// The firestore of [context].
  Future<Firestore> get firestore async => (await context).firestore;

  /// The auth of [context], as the admin api: listing and creating users is
  /// not something a client auth can do.
  ///
  /// Throws a [StateError] when the context was built with an auth service
  /// that has no admin api — anything but the admin sdk, in practice.
  Future<FirebaseAuthAdmin> get auth async {
    var auth = (await context).auth;
    if (auth is! FirebaseAuthAdmin) {
      throw StateError(
        'this auth cannot manage users, build the context with the admin sdk',
      );
    }
    return auth;
  }

  /// The selected app id, or a [StateError] naming what to do about it.
  String get requireAppId {
    var appId = this.appId;
    if (appId == null) {
      throw StateError('no app selected, use \'select app\' first');
    }
    return appId;
  }

  // --- Global level: the auth users of the firebase project ----------------

  /// The users of the firebase project, at most [maxResults] of them.
  Future<List<UserRecord>> listUsers({
    int? maxResults,
    String? pageToken,
  }) async {
    var result = await (await auth).listUsers(
      maxResults: maxResults,
      pageToken: pageToken,
    );
    return result.users.nonNulls.toList();
  }

  /// The user of [email], or null when no account has it.
  Future<UserRecord?> findUserByEmail(String email) async =>
      (await auth).getUserByEmail(email.trim());

  /// The user of [userId], or null.
  Future<UserRecord?> findUser(String userId) async =>
      (await auth).getUser(userId.trim());

  /// Creates an email/password user and returns it.
  Future<UserRecord> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return (await auth).createUser(
      FirebaseAuthCreateUserRequest(
        email: email.trim(),
        password: password,
        displayName: displayName,
      ),
    );
  }

  // --- App level: app/<appId>/user_access/<userId> --------------------------

  /// The apps of the firebase project, i.e. the existing documents of the
  /// `app` collection.
  ///
  /// A document that does not exist but holds sub collections is *not* here —
  /// a query never returns those. Use [appDocuments] to see them.
  Future<List<FsApp>> apps() async {
    initFestenaoFsBuilders();
    return fsRootCollection.get(await firestore);
  }

  /// Every document of the `app` collection, the ones that do not exist
  /// included.
  ///
  /// Firestore keeps a document id alive as soon as something hangs below it,
  /// so `app/<appId>` routinely has projects and user access while the
  /// document itself was never written — a query skips those, which is why the
  /// firestore console shows them in italics. Listing the ids of the
  /// collection is the only way to see them, and the tekartik abstraction has
  /// no `listDocuments`, so this reaches the admin sdk native instance.
  ///
  /// Throws a [StateError] when the context is not admin sdk backed.
  Future<List<FestenaoFbAppDocument>> appDocuments() async {
    initFestenaoFsBuilders();
    var firestore = await this.firestore;
    if (firestore is! FirestoreAdminSdk) {
      throw StateError(
        'listing the missing app documents needs the admin sdk firestore',
      );
    }
    var nativeRefs = await firestore.nativeInstance
        .collection(fsRootCollection.path)
        .listDocuments();
    var documents = <FestenaoFbAppDocument>[];
    for (var nativeRef in nativeRefs) {
      var ref = fsRootCollection.doc(nativeRef.id);
      var app = await firestore.refGet(ref);
      var collections = await ref.raw(firestore).listCollections();
      documents.add(
        FestenaoFbAppDocument(
          appId: nativeRef.id,
          exists: app.exists,
          name: app.exists ? app.name.v : null,
          collectionIds: collections.map((c) => c.id).toList(),
        ),
      );
    }
    return documents;
  }

  /// The app wide access document of [userId], at
  /// `app/<appId>/user_access/<userId>`.
  ///
  /// This is what makes an app admin: an admin here administers the whole app,
  /// not one of its projects.
  Future<FsUserAccess> getAppUserAccess(String userId) async =>
      (await firestore).refGet(
        fsAppUserAccessCollection(requireAppId).doc(userId),
      );

  /// The users having an app wide access, the user id being the document id of
  /// each entry.
  Future<List<FsUserAccess>> appUserAccessList() async =>
      fsAppUserAccessCollection(requireAppId).get(await firestore);

  /// Writes the app wide access of [userId].
  Future<void> setAppUserAccess(String userId, FsUserAccess userAccess) async =>
      (await firestore).refSet(
        fsAppUserAccessCollection(requireAppId).doc(userId),
        userAccess,
      );

  /// Makes [userId] an admin of the app.
  ///
  /// [name] is informative, for whoever reads the document later — the email
  /// of the user, typically.
  Future<void> grantAppAdmin(String userId, {String? name}) async {
    var userAccess = FsUserAccess()
      ..admin.v = true
      ..role.v = roleAdmin;
    if (name != null) {
      userAccess.name.v = name;
    }
    await setAppUserAccess(userId, userAccess);
  }

  /// Makes [userId] a super admin of the app.
  Future<void> grantAppSuperAdmin(String userId, {String? name}) async {
    var userAccess = FsUserAccess()
      ..admin.v = true
      ..role.v = roleSuperAdmin;
    if (name != null) {
      userAccess.name.v = name;
    }
    await setAppUserAccess(userId, userAccess);
  }

  /// Removes the app wide access of [userId].
  Future<void> revokeAppAccess(String userId) async => (await firestore)
      .refDelete(fsAppUserAccessCollection(requireAppId).doc(userId));

  // --- App project level: app/<appId>/project/<projectId> -------------------

  /// The project entity access, rooted at `app/<appId>`.
  Future<TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>>
  get projectDb async {
    initFestenaoFsBuilders();
    return TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: await firestore,
      rootDocument: fsAppRoot(requireAppId),
    );
  }

  /// The projects of the app, at `app/<appId>/project`.
  Future<List<FsProject>> projects() async {
    var db = await projectDb;
    return db.fsEntityCollectionRef.get(await firestore);
  }

  /// The sub collections of the project [projectId] (`data`, `access`, …),
  /// whether its document exists or not.
  Future<List<String>> projectCollectionIds(String projectId) async {
    var db = await projectDb;
    var collections = await db
        .fsEntityRef(projectId)
        .raw(await firestore)
        .listCollections();
    return collections.map((c) => c.id).toList();
  }

  /// The access of [userId] on the project [projectId].
  Future<TkCmsFsUserAccess> getProjectUserAccess({
    required String projectId,
    required String userId,
  }) async {
    var db = await projectDb;
    return (await firestore).refGet(
      db.fsEntityUserAccessRef(projectId, userId),
    );
  }

  /// The users having an access on the project [projectId], the user id being
  /// the document id of each entry.
  Future<List<TkCmsFsUserAccess>> projectUserAccessList(
    String projectId,
  ) async {
    var db = await projectDb;
    return db.fsEntityUserAccessCollectionRef(projectId).get(await firestore);
  }

  /// Writes the access of [userId] on the project [projectId].
  ///
  /// Both sides are written (the project's user list and the user's project
  /// list), so the project shows up for that user in the app.
  Future<void> setProjectUserAccess({
    required String projectId,
    required String userId,
    required TkCmsFsUserAccess? userAccess,
  }) async {
    var db = await projectDb;
    await db.setEntityUserAccess(
      entityId: projectId,
      userId: userId,
      userAccess: userAccess,
    );
  }

  /// Removes the access of [userId] on the project [projectId], both sides.
  Future<void> revokeProjectUserAccess({
    required String projectId,
    required String userId,
  }) async {
    await setProjectUserAccess(
      projectId: projectId,
      userId: userId,
      userAccess: null,
    );
  }
}

/// One document of the `app` collection, existing or not.
class FestenaoFbAppDocument {
  /// The document id, i.e. the app id.
  final String appId;

  /// Whether the document itself exists.
  ///
  /// False for the ids that only exist because something hangs below them.
  final bool exists;

  /// The app name, when the document exists and has one.
  final String? name;

  /// The sub collections of the document (`project`, `access`, `user_access`,
  /// …), which is what keeps a missing document alive.
  final List<String> collectionIds;

  /// One document of the `app` collection.
  FestenaoFbAppDocument({
    required this.appId,
    required this.exists,
    this.name,
    required this.collectionIds,
  });

  @override
  String toString() =>
      '$appId${exists ? '' : ' (no document)'}'
      '${name == null ? '' : ' $name'}'
      '${collectionIds.isEmpty ? '' : ' [${collectionIds.join(', ')}]'}';
}

/// The access to grant on a project, as the dev menu offers them.
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
    return userAccess;
  }
}
