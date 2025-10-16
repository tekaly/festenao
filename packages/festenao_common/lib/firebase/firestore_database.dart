import 'package:festenao_common/data/festenao_cv.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Initializes Festenao Firestore builders.
void initFestenaoFsBuilders() {
  initTkCmsFsBuilders();
  initFestenaoCvBuilders();
  cvAddConstructors([FsExport.new, FsProject.new]);
  initFsFormBuilders();
}

/// Main entity database for projects.
class FsProject extends TkCmsFsProject {
  @override
  CvFields get fields => [...super.fields];
}

/// User private entity database.
class FsUserPrv extends TkCmsFsEntity {
  /// User access, copy of the access field.
  final access = CvModelField<TkCmsCvUserAccess>('access');
  @override
  CvFields get fields => [access, ...super.fields];
}

/// Tree definition for synced collections.
final tkCmsSyncedTreeDef = TkCmsCollectionsTreeDef(
  map: {
    'data': {'data': null, 'meta': null},
  },
);

/// Project collection info.
final projectCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsProject>(
      id: projectPathPart,
      name: 'Project',
      treeDef: tkCmsSyncedTreeDef,
    );

/// User private collection info.
final userPrvCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsUserPrv>(
      id: 'project_user',
      name: 'User private',
      treeDef: tkCmsSyncedTreeDef,
    );

/// Main entity database service for Festenao.
class FestenaoFirestoreDatabase extends TkCmsFirestoreDatabaseService {
  /// Project entity database access.
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>? _projectDb;
  TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> get projectDb =>
      _projectDb!;
  set projectDb(TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> db) {
    _projectDb = db;
  }

  /// App database access.
  late TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp> appDb;

  /// User private database access.
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv> userPrvDb;

  /// Constructor for FestenaoFirestoreDatabase.
  FestenaoFirestoreDatabase({
    required super.firebaseContext,
    required super.flavorContext,
    TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>? projectDb,
  }) {
    _init(projectDb);
  }

  // ignore: unused_element
  void _init(TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>? projectDb) {
    initFestenaoFsBuilders();
    _projectDb =
        projectDb ??
        TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore,
          rootDocument: fsAppRoot(app),
        );

    userPrvDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv>(
      entityCollectionInfo: userPrvCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot(app),
    );
    appDb = TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
      entityCollectionInfo: tkCmsFsAppCollectionInfo,
      firestore: firestore,
      rootDocument: null,
    );
  }

  /// Project collection reference.
  CvCollectionReference<FsProject> get fsProjectCollection =>
      projectDb.fsEntityCollectionRef;

  /// Copy with a different appId.
  FestenaoFirestoreDatabase copyWithAppId(String appId) {
    return FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: flavorContext.copyWithAppId(appId),
    );
  }
}

/// Global entity database
FestenaoFirestoreDatabase get globalEntityDatabase =>
    globalFestenaoFirestoreDatabase;
set globalEntityDatabase(FestenaoFirestoreDatabase db) {
  globalFestenaoFirestoreDatabaseOrNull = db;
}

FestenaoFirestoreDatabase? globalFestenaoFirestoreDatabaseOrNull;

/// Global festenao firestore database
FestenaoFirestoreDatabase get globalFestenaoFirestoreDatabase =>
    globalFestenaoFirestoreDatabaseOrNull!;
