import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/form/src/fs_form_model.dart';

var fsFormQuestionCollectionInfo =
    TkCmsFirestoreDatabaseBasicEntityCollectionInfo<FsFormQuestion>(
      id: 'question',
      name: 'Question',
      //treeDef: TkCmsCollectionsTreeDef(map: {'item': null}),
    );

TkCmsFirestoreDatabaseServiceBasicEntityAccessor<FsFormQuestion>
fbFsFormQuestionAccess(FirestoreDatabaseContext firestoreDatabaseContext) =>
    TkCmsFirestoreDatabaseServiceBasicEntityAccessor<FsFormQuestion>(
      entityCollectionInfo: fsFormQuestionCollectionInfo,
      firestoreDatabaseContext: firestoreDatabaseContext,
    );
TkCmsFirestoreDatabaseServiceDocEntityAccessor<FsFormQuestion>
fbFsDocFormQuestionAccess(FirestoreDatabaseContext firestoreDatabaseContext) =>
    TkCmsFirestoreDatabaseServiceDocEntityAccessor<FsFormQuestion>(
      entityCollectionInfo: fsFormQuestionCollectionInfo,
      firestoreDatabaseContext: firestoreDatabaseContext,
    );
