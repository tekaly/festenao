import 'package:tekartik_firebase_storage_rest/storage_json.dart';

//@Deprecated('Use UnauthenticatedStorageApi from tekartik_firebase_storage_rest')
UnauthenticatedStorageApi getUnauthenticatedStorageApi(
    {String? projectId, String? storageBucket}) {
  assert(projectId != null ? storageBucket == null : storageBucket != null);
  var api = UnauthenticatedStorageApi(
      client: null, storageBucket: storageBucket ?? '$projectId.appspot.com');
  return api;
}

const storageImageDirPart = 'image';
const storageDataDirPart = 'data';
String getStoragePublishMetaFileBasename(bool dev) =>
    'export_meta${dev ? '_dev' : ''}.jsonl';
String getStoragePublishDataFileBasename(int changeId) =>
    'export_$changeId.json';
