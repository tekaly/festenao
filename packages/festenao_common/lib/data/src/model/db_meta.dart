import 'package:festenao_common/data/festenao_db.dart';

/// Abstract meta information record.
class DbMeta extends DbStringRecordBase {
  @override
  List<CvField<Object?>> get fields => <CvField<Object?>>[];
}

/// Default model instance for meta records.
var dbMetaModel = DbMeta();

/// General meta information (name, tags).
class DbMetaGeneral extends DbMeta {
  /// General name for the meta record.
  late final name = CvField<String>('name');

  late final description = CvField<String>('description');

  /// Tags associated with the meta record.
  late final tags = CvListField<String>('tags');

  @override
  late final List<CvField<Object?>> fields = [name, description, tags];
}

/// Default model instance for general meta.
var dbMetaGeneralModel = DbMetaGeneral();
