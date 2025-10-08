import 'package:tekartik_firebase_storage_rest/storage_json.dart';

/// Gets an unauthenticated storage API instance.
///
/// Either [projectId] or [storageBucket] must be provided, but not both.
UnauthenticatedStorageApi getUnauthenticatedStorageApi({
  String? projectId,
  String? storageBucket,
}) {
  assert(projectId != null ? storageBucket == null : storageBucket != null);
  var api = UnauthenticatedStorageApi(
    client: null,
    storageBucket: storageBucket ?? '$projectId.appspot.com',
  );
  return api;
}

/// Directory part for storage images.
const storageImageDirPart = 'image';

/// Directory part for storage data.
const storageDataDirPart = 'data';

/// Gets the storage publish meta file basename based on the development flag.
///
/// Returns 'export_meta_dev.jsonl' if [dev] is true, otherwise 'export_meta.jsonl'.
String getStoragePublishMetaFileBasename(bool dev) =>
    'export_meta${dev ? '_dev' : ''}.jsonl';

/// Gets the storage publish data file basename for the given change ID.
///
/// Returns 'export_[changeId].json'.
String getStoragePublishDataFileBasename(int changeId) =>
    'export_$changeId.json';
