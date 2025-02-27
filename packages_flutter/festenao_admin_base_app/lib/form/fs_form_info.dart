import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';

var fsFormQuestionCollectionInfo =
    TkCmsFirestoreDatabaseBasicEntityCollectionInfo<FsFormQuestion>(
  id: 'question',
  name: 'Question',
  //treeDef: TkCmsCollectionsTreeDef(map: {'item': null}),
);

TkCmsFirestoreDatabaseServiceBasicEntityAccess<FsFormQuestion>
    fbFsFormQuestionAccess(FirestoreDatabaseContext firestoreDatabaseContext) =>
        TkCmsFirestoreDatabaseServiceBasicEntityAccess<FsFormQuestion>(
          entityCollectionInfo: fsFormQuestionCollectionInfo,
          firestoreDatabaseContext: firestoreDatabaseContext,
        );
TkCmsFirestoreDatabaseServiceDocEntityAccess<FsFormQuestion>
    fbFsDocFormQuestionAccess(
            FirestoreDatabaseContext firestoreDatabaseContext) =>
        TkCmsFirestoreDatabaseServiceDocEntityAccess<FsFormQuestion>(
          entityCollectionInfo: fsFormQuestionCollectionInfo,
          firestoreDatabaseContext: firestoreDatabaseContext,
        );
