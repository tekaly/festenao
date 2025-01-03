import 'package:tkcms_common/tkcms_firestore.dart';

/// Initialize notelio firestore builders
void initNotelioFsBuilders() {
  cvAddConstructors([
    FsBooklet.new,
  ]);
}

/// Main entity database
class FsBooklet extends TkCmsFsEntity {
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

/// Booklet collection info
final bookletCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsBooklet>(
        id: 'project',
        name: 'Booklet',
        treeDef: TkCmsCollectionsTreeDef(map: {
          'data': {'data': null, 'meta': null}
        }));

/// User private collection info
final userPrvCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsUserPrv>(
        id: 'booklet_user',
        name: 'User private',
        treeDef: TkCmsCollectionsTreeDef(map: {
          'data': {'data': null, 'meta': null}
        }));

/// Main entity database
class FestenaoFirestoreDatabase extends TkCmsFirestoreDatabaseService {
  /// Booklet database
  late TkCmsFirestoreDatabaseServiceEntityAccess<FsBooklet> bookletDb;

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
    bookletDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsBooklet>(
        entityCollectionInfo: bookletCollectionInfo,
        firestore: firestore,
        rootDocument: fsAppRoot(app));
    userPrvDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsUserPrv>(
        entityCollectionInfo: userPrvCollectionInfo,
        firestore: firestore,
        rootDocument: fsAppRoot(app));
  }

  /// Booklet collection reference
  CvCollectionReference<FsBooklet> get fsBookletCollection =>
      bookletDb.fsEntityCollectionRef;
}

/// Global entity database
late FestenaoFirestoreDatabase globalEntityDatabase;

/// Global notelio firestore database
FestenaoFirestoreDatabase get globalNotelioFirestoreDatabase =>
    globalEntityDatabase;
