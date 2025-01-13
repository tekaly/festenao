import 'package:tkcms_common/tkcms_firestore.dart';

/// Initialize notelio firestore builders
void initNotelioFsBuilders() {
  cvAddConstructors([
    FsProject.new,
  ]);
}

/// Main entity database
class FsProject extends TkCmsFsEntity {
  @override
  CvFields get fields => [...super.fields];
}

/// `<entity>`_user/`<user_id>`/entity/`<entity>` ... prv info
class FsUserPrv extends TkCmsFsEntity {
  /// Use access
  final access = CvModelField<TkCmsCvUserAccess>('access');
  @override
  CvFields get fields => [access, ...super.fields];
}

/// Project collection info
final projectCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsProject>(
        id: 'project',
        name: 'Project',
        treeDef: TkCmsCollectionsTreeDef(map: {
          'data': {'data': null, 'meta': null}
        }));

/// User private collection info
final userPrvCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsUserPrv>(
        id: 'Project_user',
        name: 'User private',
        treeDef: TkCmsCollectionsTreeDef(map: {
          'data': {'data': null, 'meta': null}
        }));

/// Main entity database
class FestenaoFirestoreDatabase extends TkCmsFirestoreDatabaseService {
  /// Project database
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> projectDb;

  /// User private database
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv> userPrvDb;

  /// Constructor
  FestenaoFirestoreDatabase(
      {required super.firebaseContext, required super.flavorContext}) {
    _init();
  }

  // ignore: unused_element
  void _init() {
    initNotelioFsBuilders();
    projectDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
        entityCollectionInfo: projectCollectionInfo,
        firestore: firestore,
        rootDocument: fsAppRoot(app));
    userPrvDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv>(
        entityCollectionInfo: userPrvCollectionInfo,
        firestore: firestore,
        rootDocument: fsAppRoot(app));
  }

  /// Project collection reference
  CvCollectionReference<FsProject> get fsProjectCollection =>
      projectDb.fsEntityCollectionRef;
}

/// Global entity database
late FestenaoFirestoreDatabase globalEntityDatabase;

/// Global notelio firestore database
FestenaoFirestoreDatabase get globalNotelioFirestoreDatabase =>
    globalEntityDatabase;
