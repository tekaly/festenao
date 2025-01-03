import 'package:tekartik_firebase_storage_rest/storage_json.dart';

UnauthenticatedStorageApi getUnauthenticatedStorageApi(
    {required String projectId}) {
  var api = UnauthenticatedStorageApi(
      client: null, storageBucket: '$projectId.appspot.com');
  return api;
}

const storageImageDirPart = 'image';
const storageDataDirPart = 'data';
String getStoragePublishMetaFileBasename(bool dev) =>
    'export_meta${dev ? '_dev' : ''}.jsonl';
String getStoragePublishDataFileBasename(int changeId) =>
    'export_$changeId.json';
