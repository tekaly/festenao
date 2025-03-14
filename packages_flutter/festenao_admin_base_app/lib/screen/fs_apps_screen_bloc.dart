import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';

/// Apps screen bloc state
class FsAppsScreenBlocState {
  /// User
  final TkCmsFbIdentity? identity;

  /// Apps
  final List<TkCmsFsApp> apps;

  /// Apps screen bloc state
  FsAppsScreenBlocState({required this.apps, required this.identity});
}

/// Information path
String appIdAppPath(String appId) {
  return 'app/$appId';
}

/// Information path
String appIdProjectIdUserIdAppPath(
  String appId,
  String? projectId,
  String? userId,
) {
  var sb = StringBuffer();
  sb.write(appIdProjectIdAppPath(appId, projectId));

  if (userId != null) {
    sb.write('/user/$userId');
  }
  return sb.toString();
}

/// Information path
String appIdProjectIdAppPath(String appId, String? projectId) {
  var sb = StringBuffer();
  sb.write(appIdAppPath(appId));
  if (projectId != null) {
    sb.write('/project/$projectId');
  }
  return sb.toString();
}

/// Apps screen bloc
class FsAppsScreenBloc extends AutoDisposeStateBaseBloc<FsAppsScreenBlocState> {
  // ignore: cancel_subscriptions
  StreamSubscription? _firestoreSubscription;

  TkCmsFbIdentity? _fbIdentity;

  late final _lock = Lock(); // globalAppsBloc.syncLock;
  final _fsLock = Lock();
  final bool selectMode;

  void refresh() {
    assert(_fbIdentity != null);

    /// Build from firestore
    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;

    if (firestore.service.supportsTrackChanges &&
        _firestoreSubscription != null) {
      return;
    }
    audiDispose(_firestoreSubscription);

    _firestoreSubscription = audiAddStreamSubscription(
      fsDb.fsEntityCollectionRef.onSnapshotsSupport(fsDb.firestore).listen((
        list,
      ) {
        _fsLock.synchronized(() async {
          add(FsAppsScreenBlocState(apps: list, identity: _fbIdentity));
          // var AppsUser = await dbAppUserStore.record(userId).get(AppsDb.db);
        });
      }),
    );
  }

  /// Apps screen bloc
  FsAppsScreenBloc({this.selectMode = false}) {
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

                add(FsAppsScreenBlocState(apps: [], identity: identity));
              }
            }
          });
        }),
      );
    }();
  }
}
