import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';

import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class FsAppEditScreenParam {
  /// Null for creation
  final String? appId;
  FsAppEditScreenParam({required this.appId});
}

class FsAppEditScreenBlocState {
  final TkCmsFbIdentity? identity;
  final TkCmsFsApp? app;

  FsAppEditScreenBlocState({required this.identity, required this.app});
}

class FsAppEditData {
  final String appId;
  final TkCmsFsApp app;

  FsAppEditData({required this.appId, required this.app});
}

class FsAppEditScreenBloc
    extends AutoDisposeStateBaseBloc<FsAppEditScreenBlocState> {
  TkCmsFbIdentity? _fbIdentity;

  //late final _lock = Lock(); //
  final FsAppEditScreenParam param;

  //late StreamSubscription _studiesSubscription;

  FsAppEditScreenBloc({required this.param}) {
    () async {
      if (!disposed) {
        _fbIdentity = (await globalTkCmsFbIdentityBloc.state.first).identity;

        if (_fbIdentity == null) {
          add(FsAppEditScreenBlocState(identity: null, app: null));
        } else {
          var appId = param.appId ?? globalFestenaoFirestoreDatabase.app;
          var fsDb = globalFestenaoFirestoreDatabase.appDb;
          var firestore = globalFestenaoFirestoreDatabase.firestore;
          var app = await fsDb.fsEntityRef(appId).get(firestore);
          if (!disposed) {
            add(FsAppEditScreenBlocState(identity: _fbIdentity, app: app));
          }
        }
      }
    }();
  }

  Future<void> saveApp(FsAppEditData data) async {
    var appId = data.appId;

    var fsDb = globalFestenaoFirestoreDatabase.appDb;
    var firestore = globalFestenaoFirestoreDatabase.firestore;

    await fsDb.fsEntityRef(appId).set(firestore, data.app);
  }
}
