import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/festenao/cv_import.dart';

//
/// Document for firestore export.
class FsExport extends CvFirestoreDocumentBase {
  /// The timestamp of the export.
  final timestamp = CvField<Timestamp>('timestamp');

  /// The version of the export.
  final version = CvField<int>('version');

  /// The change ID.
  final changeId = CvField<int>('changeId');

  /// The size of the export.
  final size = CvField<int>('size');

  @override
  List<CvField> get fields => [version, timestamp, changeId, size];
}

/// Default model instance for [FsExport].
final fsExportModel = FsExport();
