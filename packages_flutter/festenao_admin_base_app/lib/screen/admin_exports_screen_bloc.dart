import 'dart:async';

import 'package:festenao_admin_base_app/screen/admin_export_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';

class AdminExportsScreenBlocState {
  final List<FsExport> list;
  FestenaoExportMeta? metaDev;
  FestenaoExportMeta? metaProd;

  AdminExportsScreenBlocState(
    this.list, {
    required this.metaDev,
    required this.metaProd,
  });
}

class AdminExportsScreenBloc
    extends AutoDisposeStateBaseBloc<AdminExportsScreenBlocState>
    with AdminExportBlocMixin {
  // ignore: cancel_subscriptions
  StreamSubscription? _artistSubscription;

  @override
  final FestenaoAdminAppProjectContext projectContext;

  AdminExportsScreenBloc({required this.projectContext}) {
    refresh();
  }

  Future<void> refresh() async {
    var firestore = projectContext.firestore;
    Future<void> addExports(List<FsExport> exports) async {
      FestenaoExportMeta? metaDev;
      FestenaoExportMeta? metaProd;

      var metaDevSnapshot =
          await firestore
              .collection(firestoreMetaCollectionPath)
              .doc(getFirestorePublishMetaDocumentName(true))
              // globalFestenaoAppFirebaseContext              .getMetaExportFirestorePath(false))
              .get();
      /*firestore
          .doc(
              globalFestenaoAppFirebaseContext.getMetaExportFirestorePath(true))
          .get();*/
      if (metaDevSnapshot.exists) {
        metaDev = metaDevSnapshot.data.cv<FestenaoExportMeta>();
      }
      var metaProdSnapshot =
          await firestore
              .collection(firestoreMetaCollectionPath)
              .doc(getFirestorePublishMetaDocumentName(false))
              // globalFestenaoAppFirebaseContext              .getMetaExportFirestorePath(false))
              .get();
      if (metaProdSnapshot.exists) {
        metaProd = metaProdSnapshot.data.cv<FestenaoExportMeta>();
      }
      add(
        AdminExportsScreenBlocState(
          exports,
          metaDev: metaDev,
          metaProd: metaProd,
        ),
      );
    }

    var query = firestore.collection(firestoreExportCollectionPath);
    if (firestore.service.supportsTrackChanges) {
      _artistSubscription ??= audiAddStreamSubscription(
        query.onSnapshotSupport().listen((event) async {
          await addExports(event.docs.cv<FsExport>());
        }),
      );
    } else {
      await addExports(await query.cvGet<FsExport>());
    }
  }
}
