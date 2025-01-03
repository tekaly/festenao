import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_firestore.dart';

void initBuilder() {
  cvFirestoreAddBuilder<FsUserAccess>((_) => FsUserAccess());
  cvFirestoreAddBuilder<FsExport>((_) => FsExport());
  cvFirestoreAddBuilder<FestenaoExportMeta>((_) => FestenaoExportMeta());
}
