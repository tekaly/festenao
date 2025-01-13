import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_common/data/festenao_db.dart';

Future<DbImage?> getDbImage(String imageId) async {
  var db = globalProjectsDb.db;
  return dbImageStoreRef.record(imageId).get(db);
}
