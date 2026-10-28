/// Who chooses a slug, when an app keeps it to a few users: the app admins
/// and the users holding the app [festenaoSlugRole]; everyone else gets the
/// generated id in the url (`/p/<projectId>`).
///
/// The right is the app access document of the user, the one the server and
/// the rules check (`access/app/entity_id/<app>/user_access/<userId>`):
/// `admin: true`, or [festenaoSlugRole] among its roles (`role`, comma
/// separated). The rules enforce it when built with the app right
/// (`festenao_firebase` `addSlugRules(appRight: true)`).
library;

import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

/// The app role of the users who choose slugs (besides the app admins).
const festenaoSlugRole = 'slug';

/// The slug right of an app access document.
extension FestenaoSlugUserAccessExt on TkCmsFsUserAccess {
  /// True for an app admin or a holder of [festenaoSlugRole].
  bool get canSetSlug => exists && (isAdmin || hasRole(festenaoSlugRole));

  /// Grant or revoke [festenaoSlugRole], the other roles kept.
  void setSlugRole(bool granted) {
    var roles = this.roles.where((role) => role != festenaoSlugRole).toList();
    if (granted) {
      roles.add(festenaoSlugRole);
    }
    role.v = roles.isEmpty ? null : roles.join(',');
  }
}

/// The slug right of the users of an app.
extension FestenaoFirestoreDatabaseSlugRightsExt on FestenaoFirestoreDatabase {
  /// The app access document of [userId] (the one the rules check).
  CvDocumentReference<TkCmsFsUserAccess> appUserAccessRef(String userId) =>
      appDb.fsEntityUserAccessRef(app, userId);

  /// True when [userId] may choose a slug (see [FestenaoSlugUserAccessExt]).
  Future<bool> canSetSlug(String userId) async =>
      (await appUserAccessRef(userId).get(firestore)).canSetSlug;

  /// The app access of [userId], live.
  Stream<TkCmsFsUserAccess> onAppUserAccess(String userId) =>
      appUserAccessRef(userId).onSnapshotSupport(firestore);

  /// The slug right of [userId], live.
  Stream<bool> onCanSetSlug(String userId) =>
      onAppUserAccess(userId).map((access) => access.canSetSlug).distinct();
}
