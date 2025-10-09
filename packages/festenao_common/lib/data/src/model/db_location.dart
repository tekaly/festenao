import 'package:festenao_common/data/festenao_db.dart';

/// Location record stored in the database.
///
/// Contains a human-friendly name and optional attributes/links.
class DbLocation extends DbStringRecordBase {
  /// Location name (displayed in UI).
  final name = CvField<String>('name');

  /// Attributes or links associated with the location.
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );

  @override
  List<CvField> get fields => [name, attributes];
}
