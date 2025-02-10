import 'package:festenao_common/data/festenao_db.dart';

extension FestenaoAppProjectDbExt on Database {
  Future<DbImage?> getDbImage(String imageId) async {
    return dbImageStoreRef.record(imageId).get(this);
  }
}
