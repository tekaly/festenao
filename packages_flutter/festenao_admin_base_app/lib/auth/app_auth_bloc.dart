import 'dart:async';

import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_app_rx_bloc/auto_dispose_state_base_bloc.dart';
import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tkcms_common/tkcms_auth.dart';

class AppAuthBlocState {
  final TkCmsFbIdentity? identity;
  final TkCmsEditedFsUserAccess? userAccess;
  FirebaseUser? get user => identity?.user;

  AppAuthBlocState({required this.identity, this.userAccess});

  @override
  String toString() => '$identity $userAccess';
}

class AppAuthBloc extends AutoDisposeStateBaseBloc<AppAuthBlocState> {
  final CvDocumentReference app;
  StreamSubscription? _userAccessSubscription;
  AppAuthBloc(this.app) {
    String? identityId;
    audiAddStreamSubscription(
      globalTkCmsFbIdentityBloc.state.listen((state) {
        var identity = state.identity;
        if (identity?.isServiceAccount ?? false) {
          identityId = identity!.userOrAccountId;
          _userAccessSubscription?.cancel();
          add(
            AppAuthBlocState(
              identity: identity,
              userAccess: TkCmsEditedFsUserAccess()..grantSuperAdminAccess(),
            ),
          );
        } else if (identity?.isUser ?? false) {
          var newIdentityId = identity!.userOrAccountId;
          if (newIdentityId != identityId) {
            // Identity changed
            identityId = newIdentityId;
            _userAccessSubscription?.cancel();
            // Load user access
            var firestore = globalFestenaoFirestoreDatabase.appDb.firestore;
            var ref = globalFestenaoFirestoreDatabase.appDb
                .fsUserEntityAccessRef(newIdentityId, app.id)
                .cast<TkCmsEditedFsUserAccess>();
            _userAccessSubscription = audiAddStreamSubscription(
              ref
                  .onSnapshotSupport(firestore)
                  .listen(
                    (snapshot) {
                      var userAccess = snapshot;
                      add(
                        AppAuthBlocState(
                          identity: identity,
                          userAccess: userAccess,
                        ),
                      );
                    },
                    onError: (Object e) {
                      if (isDebug) {
                        // ignore: avoid_print
                        print('Error loading user access: $e');
                      }
                      add(
                        AppAuthBlocState(identity: identity, userAccess: null),
                      );
                    },
                  ),
            );
          }
        } else {
          _userAccessSubscription?.cancel();
          identityId = null;
          // Not signed in
          add(AppAuthBlocState(identity: null, userAccess: null));
        }
      }),
    );
  }
}

AppAuthBloc? globalFestenaoAppAuthBlocOrNull;
AppAuthBloc get globalFestenaoAppAuthBloc => globalFestenaoAppAuthBlocOrNull!;
