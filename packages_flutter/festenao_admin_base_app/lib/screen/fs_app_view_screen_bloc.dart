import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

class FsAppViewScreenBlocState {
  final TkCmsFbIdentity? identity;
  final TkCmsFsApp? app;

  FsAppViewScreenBlocState({this.app, this.identity});
}

abstract class FsAppBlocRawBase<T extends Object>
    extends AutoDisposeStateBaseBloc<T> {
  Firestore get firestore => ffdb.firestore;
  TkCmsFbIdentity? fbIdentity;

  String? get userId => firebaseUser?.uid;

  /// Null for service account
  FirebaseUser? get firebaseUser => (fbIdentity is TkCmsFbIdentityUser)
      ? (fbIdentity as TkCmsFbIdentityUser).user
      : null;

  /// Null for app create only
  final String? appId;

  String get appIdOrDefault => appId ?? globalFestenaoFirestoreDatabase.appId;

  /// Projects screen bloc
  FsAppBlocRawBase({required this.appId});
  late final identityLock = Lock(); // globalProjectsBloc.syncLock;
  final fsLock = Lock();

  late final FestenaoFirestoreDatabase ffdb = () {
    if (appIdOrDefault == globalFestenaoFirestoreDatabase.appId) {
      return globalFestenaoFirestoreDatabase;
    }
    return globalFestenaoFirestoreDatabase.copyWithAppId(appIdOrDefault);
  }();

  /// App or project user helper
  CvCollectionReference<TkCmsFsUserAccess> appOrProjectUserAccessCollectionRef({
    String? projectId,
  }) {
    var ffdb = this.ffdb;
    if (projectId != null) {
      return ffdb.projectDb.fsEntityUserAccessCollectionRef(projectId);
    } else {
      return ffdb.appDb.fsEntityUserAccessCollectionRef(appIdOrDefault);
    }
  }

  /// App or project user helper
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> appOrProjectAccess({
    String? projectId,
  }) {
    var ffdb = this.ffdb;
    if (projectId != null) {
      return ffdb.projectDb;
    } else {
      return ffdb.appDb;
    }
  }
}

abstract class FsAppBlocBase<T extends Object> extends FsAppBlocRawBase<T> {
  // ignore: cancel_subscriptions
  StreamSubscription? fsSubscription;

  void refresh() {
    assert(fbIdentity != null);
    var ffdb = this.ffdb;
    var firestore = ffdb.firestore;

    if (firestore.service.supportsTrackChanges && fsSubscription != null) {
      return;
    }
    audiDispose(fsSubscription);
    handleRefresh();
  }

  @protected
  void handleRefresh();
  @protected
  void handleNoIdentity();

  /// Projects screen bloc
  FsAppBlocBase({required super.appId}) {
    () async {
      audiAddStreamSubscription(
        globalTkCmsFbIdentityBloc.state.listen((state) {
          identityLock.synchronized(() async {
            var identity = state.identity;

            if (identity != null && (fbIdentity != identity)) {
              fbIdentity = identity;

              handleRefresh();
            } else {
              if (identity == null) {
                fbIdentity = null;
                handleNoIdentity();
              }
            }
          });
        }),
      );
    }();
  }
}

class FsAppViewScreenBloc extends FsAppBlocBase<FsAppViewScreenBlocState> {
  String get _appId => appId!;

  FsAppViewScreenBloc({required String appId}) : super(appId: appId);

  @override
  void handleRefresh() {
    /// Build from firestore
    var fsDb = ffdb.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;

    if (firestore.service.supportsTrackChanges && fsSubscription != null) {
      return;
    }
    fsSubscription = audiAddStreamSubscription(
      fsDb.fsEntityRef(_appId).onSnapshotSupport(fsDb.firestore).listen((app) {
        add(FsAppViewScreenBlocState(app: app, identity: fbIdentity));
        // var AppsUser = await dbAppUserStore.record(userId).get(AppsDb.db);
      }),
    );
  }

  @override
  void handleNoIdentity() {
    add(FsAppViewScreenBlocState(app: null, identity: null));
  }

  /// Raw delete (no child delete)
  Future<void> deleteApp(TkCmsFsApp app) async {
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;
    await fsDb.fsEntityRef(app.id).delete(firestore);
  }
}
