import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/festenao/cv_import.dart';

//
class FsExport extends CvFirestoreDocumentBase {
  final timestamp = CvField<Timestamp>('timestamp');
  final version = CvField<int>('version');
  final changeId = CvField<int>('changeId');
  final size = CvField<int>('size');

  @override
  List<CvField> get fields => [version, timestamp, changeId, size];
}

final fsExportModel = FsExport();
