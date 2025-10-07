import 'package:festenao_common/data/festenao_cv.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Initialize festenao firestore builders
void initFestenaoFsBuilders() {
  initTkCmsFsBuilders();
  initFestenaoCvBuilders();
  cvAddConstructors([FsExport.new, FsProject.new]);
  initFsFormBuilders();
}

/// Main entity database
class FsProject extends TkCmsFsProject {
  @override
  CvFields get fields => [...super.fields];
}

/// `<entity>`_user/`<user_id>`/entity/`<entity>` ... prv info
class FsUserPrv extends TkCmsFsEntity {
  /// User access, copy of the access field
  final access = CvModelField<TkCmsCvUserAccess>('access');
  @override
  CvFields get fields => [access, ...super.fields];
}

/// Project collection info
final projectCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsProject>(
      id: projectPathPart,
      name: 'Project',
      treeDef: TkCmsCollectionsTreeDef(
        map: {
          'data': {'data': null, 'meta': null},
        },
      ),
    );

/// User private collection info
final userPrvCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsUserPrv>(
      id: 'project_user',
      name: 'User private',
      treeDef: TkCmsCollectionsTreeDef(
        map: {
          'data': {'data': null, 'meta': null},
        },
      ),
    );

/// Main entity database
class FestenaoFirestoreDatabase extends TkCmsFirestoreDatabaseService {
  /// Project entity - could be for each app
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> projectDb;

  /// App database (and user access if any) - same for all apps
  late TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp> appDb;

  /// User private database
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv> userPrvDb;

  /// Constructor
  FestenaoFirestoreDatabase({
    required super.firebaseContext,
    required super.flavorContext,
  }) {
    _init();
  }

  // ignore: unused_element
  void _init() {
    initFestenaoFsBuilders();
    projectDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
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

  /// Project collection reference
  CvCollectionReference<FsProject> get fsProjectCollection =>
      projectDb.fsEntityCollectionRef;

  /// Copy with a different appId
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
