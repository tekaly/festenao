/// The app entity of the app (`app/<appId>`): its email invites checked at
/// sign in (an invite to administrate the app), the access of the signed in
/// user to it (an app admin, a super admin).
library;

import 'dart:async';

import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The app entity of the app: [entityId] of [entityAccess] (the other apps of
/// the firebase project ignored).
class FestenaoAppEntity {
  /// The app entities (`app/<appId>`).
  final TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity> entityAccess;

  /// The app.
  final String entityId;

  /// The app entity [entityId] of [entityAccess].
  const FestenaoAppEntity({required this.entityAccess, required this.entityId});
}

/// The app entity of the app, null (the default) for none: an app overrides
/// it with its own (`appDb`, its app id). Its email invites are then checked
/// at sign in (`rpdPendingEmailInvitesProvider`), and
/// [rpdAppUserAccessProvider] reads the access of the user to it.
final festenaoAppEntityProvider = Provider<FestenaoAppEntity?>(
  (ref) => null,
  name: 'festenaoAppEntity',
);

/// The access of the signed in user to the app entity
/// ([festenaoAppEntityProvider]), followed live (an accepted invite shows):
/// null when signed out, without an app entity, without an access, or when
/// the rules refuse to read it (only an admin of the app reads it).
final rpdAppUserAccessProvider = StreamProvider<TkCmsFsUserAccess?>((ref) {
  var userId = ref.watch(rpdIdentityProvider)?.userId;
  var appEntity = ref.watch(festenaoAppEntityProvider);
  if (userId == null || appEntity == null) {
    return Stream.value(null);
  }
  var entityAccess = appEntity.entityAccess;
  return entityAccess
      .fsEntityUserAccessRef(appEntity.entityId, userId)
      .onSnapshot(entityAccess.firestore)
      .map<TkCmsFsUserAccess?>((access) => access.exists ? access : null)
      .transform(
        StreamTransformer<TkCmsFsUserAccess?, TkCmsFsUserAccess?>.fromHandlers(
          handleError: (error, stackTrace, sink) => sink.add(null),
        ),
      );
}, name: 'rpdAppUserAccess');
