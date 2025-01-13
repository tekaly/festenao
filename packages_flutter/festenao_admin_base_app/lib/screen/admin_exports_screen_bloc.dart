import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firebase.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:path/path.dart';

class AdminExportsScreenBlocState {
  final List<FsExport> list;
  FestenaoExportMeta? metaDev;
  FestenaoExportMeta? metaProd;

  AdminExportsScreenBlocState(this.list,
      {required this.metaDev, required this.metaProd});
}

class AdminExportsScreenBloc extends BaseBloc {
  final _state = BehaviorSubject<AdminExportsScreenBlocState>();

  ValueStream<AdminExportsScreenBlocState> get state => _state;
  StreamSubscription? _artistSubscription;

  final String projectId;

  AdminExportsScreenBloc({required this.projectId}) {
    refresh();
  }

  Future<void> refresh() async {
    var firestore = globalFirebaseContext.firestore;
    Future<void> add(List<FsExport> exports) async {
      FestenaoExportMeta? metaDev;
      FestenaoExportMeta? metaProd;

      var metaDevSnapshot = await firestore
          .doc(globalFestenaoFirebaseContext.getMetaExportFirestorePath(true))
          .get();
      if (metaDevSnapshot.exists) {
        metaDev = metaDevSnapshot.data.cv<FestenaoExportMeta>();
      }
      var metaProdSnapshot = await firestore
          .doc(globalFestenaoFirebaseContext.getMetaExportFirestorePath(false))
          .get();
      if (metaProdSnapshot.exists) {
        metaProd = metaProdSnapshot.data.cv<FestenaoExportMeta>();
      }
      _state.add(AdminExportsScreenBlocState(exports,
          metaDev: metaDev, metaProd: metaProd));
    }

    var query = firestore.collection(url.join(
        globalFestenaoFirebaseContext.firestoreRootPath, getExportsPath()));
    if (firestore.service.supportsTrackChanges) {
      _artistSubscription ??= query.onSnapshotSupport().listen((event) async {
        await add(event.docs.cv<FsExport>());
      });
    } else {
      await add(await query.cvGet<FsExport>());
    }
  }

  @override
  void dispose() {
    _artistSubscription?.cancel();
    _state.close();
    super.dispose();
  }
}
