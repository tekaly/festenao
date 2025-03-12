import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

class FsAppViewScreenBlocState {
  final TkCmsFbIdentity? identify;
  final TkCmsFsApp? app;

  FsAppViewScreenBlocState({this.app, this.identify});
}

class FsAppViewScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppViewScreenBlocState> {
  final String appId;

  final _lock = Lock();
  // ignore: cancel_subscriptions
  StreamSubscription? fsSubscription;
  String get userId => firebaseUser!.uid;
  FirebaseUser? firebaseUser;
  TkCmsFbIdentity? _fbIdentity;

  void refresh() {
    assert(_fbIdentity != null);

    /// Build from firestore
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;

    if (firestore.service.supportsTrackChanges && fsSubscription != null) {
      return;
    }
    audiDispose(fsSubscription);

    fsSubscription = audiAddStreamSubscription(
      fsDb.fsEntityRef(appId).onSnapshotSupport(fsDb.firestore).listen((app) {
        add(FsAppViewScreenBlocState(app: app, identify: _fbIdentity));
        // var AppsUser = await dbAppUserStore.record(userId).get(AppsDb.db);
      }),
    );
  }

  FsAppViewScreenBloc({required this.appId}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          _lock.synchronized(() async {
            var identity = state.identity;

            if (identity != null && (_fbIdentity != identity)) {
              _fbIdentity = identity;

              refresh();
            } else {
              if (identity == null) {
                _fbIdentity = null;

                add(FsAppViewScreenBlocState(app: null, identify: identity));
              }
            }
          });
        }),
      );
    }();
  }

  /// Raw delete (no child delete)
  Future<void> deleteApp(TkCmsFsApp app) async {
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;
    await fsDb.fsEntityRef(app.id).delete(firestore);
  }
}
