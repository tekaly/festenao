import 'package:festenao_common/data/festenao_db.dart';

/// Abstract meta information
class DbMeta extends DbStringRecordBase {
  @override
  List<CvField<Object?>> get fields => <CvField<Object?>>[];
}

/// Model
var dbMetaModel = DbMeta();

class DbMetaGeneral extends DbMeta {
  late final name = CvField<String>('name');
  late final tags = CvListField<String>('tags');

  @override
  late final List<CvField<Object?>> fields = [name, tags];
}

var dbMetaGeneralModel = DbMetaGeneral();
