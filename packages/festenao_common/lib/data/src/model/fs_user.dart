import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/festenao/cv_import.dart';
import 'package:path/path.dart';

class FsUserAccess extends CvFirestoreDocumentBase {
  /// User id!
  String get userId => url.basename(path);

  final admin = CvField<bool>('admin');
  final name = CvField<String>('name');
  @override
  List<CvField> get fields => [admin, name];
}
