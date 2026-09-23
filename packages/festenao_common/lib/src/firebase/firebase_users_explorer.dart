import 'package:tekartik_firebase_auth/auth.dart';
import 'package:tekartik_firebase_auth/auth_admin.dart';

import '../data/model/object_source.dart' show ReadOnlyException;

/// Every field of [record] its backend reports, by name.
///
/// A backend implements only part of [UserRecord], the rest throwing, so each
/// field is read on its own and left out when it throws, is null or is empty.
/// The names are the [UserRecord] ones, `creationTime` and `lastSignInTime`
/// coming from its metadata and `providers` listing the provider ids. The
/// password hash and salt are never read.
Map<String, Object?> firebaseUserRecordFields(UserRecord record) {
  var fields = <String, Object?>{'uid': record.uid};
  void add(String name, Object? Function() read) {
    Object? value;
    try {
      value = read();
    } catch (_) {
      // Not implemented by this backend.
      return;
    }
    if (value == null ||
        (value is String && value.isEmpty) ||
        (value is List && value.isEmpty)) {
      return;
    }
    fields[name] = value;
  }

  add('email', () => record.email);
  add('displayName', () => record.displayName);
  add('phoneNumber', () => record.phoneNumber);
  add('photoURL', () => record.photoURL);
  add('emailVerified', () => record.emailVerified);
  add('isAnonymous', () => record.isAnonymous);
  add('disabled', () => record.disabled);
  add('creationTime', () => record.metadata?.creationTime);
  add('lastSignInTime', () => record.metadata?.lastSignInTime);
  add(
    'providers',
    () => record.providerData?.map((info) => info.providerId).nonNulls.toList(),
  );
  add('customClaims', () => record.customClaims);
  add('tokensValidAfterTime', () => record.tokensValidAfterTime);
  return fields;
}

/// One user of a [FirebaseUsersExplorer], read once from its [UserRecord].
class FirebaseUserEntry {
  /// The record the backend answered.
  final UserRecord record;

  /// Every field the backend reports, see [firebaseUserRecordFields].
  final Map<String, Object?> fields;

  /// Entry of [record].
  FirebaseUserEntry(this.record) : fields = firebaseUserRecordFields(record);

  /// The uid.
  String get uid => record.uid;

  /// The primary email, if any.
  String? get email => fields['email'] as String?;

  /// The display name, if any.
  String? get displayName => fields['displayName'] as String?;

  /// True for an anonymous user.
  bool get isAnonymous => fields['isAnonymous'] == true;

  /// True when the email is verified.
  bool get emailVerified => fields['emailVerified'] == true;

  /// True for a user that cannot sign in.
  bool get isDisabled => fields['disabled'] == true;

  /// What a listing names the user by: the display name, else the email, else
  /// the uid.
  String get label => displayName ?? email ?? uid;

  @override
  String toString() => 'FirebaseUserEntry($uid, $label)';
}

/// One page of [FirebaseUsersExplorer.list].
class FirebaseUsersPage {
  /// The users of the page.
  final List<FirebaseUserEntry> users;

  /// The token getting the next page, null on the last one.
  final String? nextPageToken;

  /// Page of [users].
  FirebaseUsersPage(this.users, {this.nextPageToken});

  /// True when there is a next page.
  bool get hasMore => nextPageToken != null;
}

/// Browsing the users of a [FirebaseAuth].
///
/// What it reaches depends on the backend: it lists the users page by page
/// when the service can ([canList]), looks one up by uid or email when the
/// backend answers that, and creates or deletes one through
/// [FirebaseAuthAdmin] ([canWrite]). The admin sdk and the local sdb backend
/// do all of it; the rest api with a service account lists and looks users up
/// (`firebaseAuthServiceRestAdmin`).
///
/// A read only explorer refuses every write, so handing one out is all it
/// takes to make a view read only.
///
/// ```dart
/// var explorer = FirebaseUsersExplorer(auth: auth);
/// var page = await explorer.list();
/// ```
class FirebaseUsersExplorer {
  /// The auth whose users are browsed.
  final FirebaseAuth auth;

  /// True to browse without writing.
  final bool isReadOnly;

  /// How many users a page holds at most.
  final int pageSize;

  /// Explorer of the users of [auth].
  FirebaseUsersExplorer({
    required this.auth,
    this.isReadOnly = false,
    this.pageSize = 100,
  });

  /// The same explorer, read only.
  FirebaseUsersExplorer get readOnly => isReadOnly
      ? this
      : FirebaseUsersExplorer(auth: auth, isReadOnly: true, pageSize: pageSize);

  /// True when the users can be listed, see
  /// [FirebaseAuthService.supportsListUsers].
  bool get canList => auth.service.supportsListUsers;

  /// True when a user can be created or deleted: an admin auth, in an
  /// explorer that is not read only.
  bool get canWrite => !isReadOnly && auth is FirebaseAuthAdmin;

  /// A page of users, the first one without [pageToken].
  ///
  /// Throws when the backend cannot list them, see [canList].
  Future<FirebaseUsersPage> list({String? pageToken}) async {
    var result = await auth.listUsers(
      maxResults: pageSize,
      pageToken: pageToken,
    );
    var users = result.users.nonNulls.map(FirebaseUserEntry.new).toList();
    var nextPageToken = result.pageToken;
    // Some backends hand a token even past their last user: an empty page, or
    // a token that does not move, ends the listing.
    if (users.isEmpty || nextPageToken == pageToken) {
      nextPageToken = null;
    }
    return FirebaseUsersPage(users, nextPageToken: nextPageToken);
  }

  /// The user of uid [uid], null when there is none.
  Future<FirebaseUserEntry?> get(String uid) async {
    var record = await auth.getUser(uid);
    return record == null ? null : FirebaseUserEntry(record);
  }

  /// Looks a user up by [query]: an email when it holds an `@`, then a uid;
  /// null when there is none.
  Future<FirebaseUserEntry?> find(String query) async {
    var text = query.trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.contains('@')) {
      var record = await auth.getUserByEmail(text);
      if (record != null) {
        return FirebaseUserEntry(record);
      }
    }
    return get(text);
  }

  FirebaseAuthAdmin _admin(String what) {
    if (isReadOnly) {
      throw ReadOnlyException(what);
    }
    var auth = this.auth;
    if (auth is! FirebaseAuthAdmin) {
      throw UnsupportedError('${auth.runtimeType} cannot $what');
    }
    return auth;
  }

  /// Creates a user, see [canWrite].
  Future<FirebaseUserEntry> create(
    FirebaseAuthCreateUserRequest request,
  ) async =>
      FirebaseUserEntry(await _admin('create a user').createUser(request));

  /// Deletes the user of uid [uid], see [canWrite].
  Future<void> delete(String uid) async {
    await _admin('delete $uid').deleteUser(uid);
  }
}
