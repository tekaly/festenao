import 'package:cv/cv.dart';
import 'package:tkcms_common/tkcms_auth.dart';

export 'package:tekartik_firebase_auth/auth.dart';
export 'package:tkcms_common/tkcms_auth.dart';

extension TkCmsFbIdentityExt on TkCmsFbIdentity {
  String? get userLocalId => userOrAccountId;
  String? get userOrAccountId {
    var user = this.user;
    if (user != null) {
      return user.uid;
    }
    if (this is TkCmsFbIdentityServiceAccount) {
      return TkCmsFbIdentityServiceAccount.userLocalId;
    }
    return null;
  }

  TkCmsFbIdentityUser? get _asUserOrNull => anyAs<TkCmsFbIdentityUser?>();
  TkCmsFbIdentityServiceAccount? get _asServiceAccountOrNull =>
      anyAs<TkCmsFbIdentityServiceAccount?>();

  /// Only for user identity
  String? get userId => user?.uid;

  /// Only for user identity
  FirebaseUser? get user => _asUserOrNull?.user;

  /// Only for service account identity
  String? get serviceAccountProjectId => _asServiceAccountOrNull?.projectId;
}
