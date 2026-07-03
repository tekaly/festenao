import 'package:festenao_common/festenao_api.dart';

/// Firestore get document query.
class FirestoreDocGetQuery extends ApiQuery {
  /// Firestore document path (e.g. `collection/docId`).
  late final path = CvField<String>('path');

  @override
  late final CvFields fields = [path];
}

/// Firestore get document result.
class FirestoreDocGetResult extends ApiResult {
  /// True if the document exists.
  late final exists = CvField<bool>('exists');

  /// Document data, null if the document does not exist.
  late final data = CvField<Map>('data');

  @override
  late final CvFields fields = [exists, data];
}

/// Firestore set document query.
class FirestoreDocSetQuery extends ApiQuery {
  /// Firestore document path (e.g. `collection/docId`).
  late final path = CvField<String>('path');

  /// Document data to write.
  late final data = CvField<Map>('data');

  @override
  late final CvFields fields = [path, data];
}

/// Firestore set document result.
class FirestoreDocSetResult extends ApiResult {}

bool _firestoreDocApiBuildersInitialized = false;

/// Init firestore doc API builders.
void initFirestoreDocApiBuilders() {
  if (!_firestoreDocApiBuildersInitialized) {
    _firestoreDocApiBuildersInitialized = true;
    initTkCmsApiBuilders();
    cvAddConstructors([
      FirestoreDocGetQuery.new,
      FirestoreDocGetResult.new,
      FirestoreDocSetQuery.new,
      FirestoreDocSetResult.new,
    ]);
  }
}

/// Firestore doc API service/helper, giving raw read/write access to a
/// single Firestore document through the REST/callable API.
class FirestoreDocApiService extends FestenaoApiService {
  /// Get document command.
  static const getCommand = 'firestore/get';

  /// Set document command.
  static const setCommand = 'firestore/set';

  /// Constructor.
  FirestoreDocApiService({
    super.httpClientFactory,
    super.httpsApiUri,
    super.callableApi,
    super.app,
  }) {
    initFirestoreDocApiBuilders();
  }

  /// Reads a document at [path], returns `null` if it does not exist.
  Future<Map<String, Object?>?> getDoc(String path) async {
    var result = await getApiResult<FirestoreDocGetResult>(
      (FirestoreDocGetQuery()..path.v = path).request(getCommand),
    );
    if (result.exists.v != true) {
      return null;
    }
    return result.data.v?.cast<String, Object?>();
  }

  /// Writes [data] at document [path].
  Future<void> setDoc(String path, Map<String, Object?> data) async {
    await getApiResult<FirestoreDocSetResult>(
      (FirestoreDocSetQuery()
            ..path.v = path
            ..data.v = data)
          .request(setCommand),
    );
  }
}
