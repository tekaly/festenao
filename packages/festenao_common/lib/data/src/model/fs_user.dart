import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/festenao/cv_import.dart';
import 'package:path/path.dart';

/// Deprecated use TkCmsFsUserAccess
class FsUserAccess extends CvFirestoreDocumentBase {
  /// User id!
  String get userId => url.basename(path);

  /// True if the user is an admin.
  final admin = CvField<bool>('admin');

  /// The name of the user.
  final name = CvField<String>('name');
  @override
  List<CvField> get fields => [admin, name];
}
