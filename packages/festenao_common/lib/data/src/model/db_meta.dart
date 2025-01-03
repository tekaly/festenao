import 'package:festenao_common/data/festenao_db.dart';

/// Abstract meta information
class DbMeta extends DbStringRecordBase {
  @override
  List<CvField<Object?>> get fields => <CvField<Object?>>[];
}

/// Model
var dbMetaModel = DbInfo();

class DbMetaGeneral extends DbMeta {
  late final name = CvField<String>('name');

  @override
  late final List<CvField<Object?>> fields = [name];
}

var dbMetaGeneralModel = DbMetaGeneral();
