import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:festenao_common/data/festenao_db.dart';

Future<DbImage?> getDbImage(String imageId) async {
  var db = globalBookletsDb.db;
  return dbImageStoreRef.record(imageId).get(db);
}
