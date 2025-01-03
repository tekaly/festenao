import 'package:festenao_common/data/festenao_db.dart';

/// Artist id must allow sorting (i.e. typically lastname_firstname
// @Deprecated('Not used yet')
class DbLocation extends DbStringRecordBase {
  /// Event name
  final name = CvField<String>('name');

  /// Attributes/Links
  final attributes =
      CvModelListField<CvAttribute>('attributes', (_) => CvAttribute());

  @override
  List<CvField> get fields => [name, attributes];
}
