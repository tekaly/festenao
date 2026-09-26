import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firebase_auth.dart';
import 'package:festenao_common/firebase/firebase_users_explorer.dart';
import 'package:flutter/material.dart';

import 'firebase_users_explorer_flutter.dart';

/// The app wide user access collection of [appId]
/// (`app/<appId>/user_access`): one tkcms [TkCmsFsUserAccess] per user id.
CvCollectionReference<TkCmsFsUserAccess> festenaoAppUserAccessCollection(
  String appId,
) => fsAppRoot(
  appId,
).collection<TkCmsFsUserAccess>(tkCmsFsUserAccessCollectionId);

/// Manages the app wide user access of [appId]
/// (`app/<appId>/user_access/<userId>`, [TkCmsFsUserAccess]): who is an app
/// admin ([TkCmsCvUserAccessCommonExt.isAdmin]).
///
/// It writes the documents directly, so it needs a [firestore] that may:
/// the admin sdk, or a local backend. With an [auth] (the admin sdk one) a
/// user is added by email and the auth users can be browsed; without it,
/// by user id only. The name given when granted (the email, usually) is
/// kept in the document ([TkCmsEditedFsUserAccess.name]).
///
/// ```dart
/// await goToFestenaoAppUserAccessScreen(
///   context,
///   firestore: firestore,
///   appId: 'my_app-dev',
///   auth: auth,
/// );
/// ```
class FestenaoAppUserAccessScreen extends StatefulWidget {
  /// The Firestore holding the access documents.
  final Firestore firestore;

  /// The app id.
  final String appId;

  /// The auth whose users are granted, to find them by email.
  final FirebaseAuth? auth;

  /// The screen title, `Users of <appId>` by default.
  final String? title;

  /// The app user access screen.
  const FestenaoAppUserAccessScreen({
    super.key,
    required this.firestore,
    required this.appId,
    this.auth,
    this.title,
  });

  @override
  State<FestenaoAppUserAccessScreen> createState() =>
      _FestenaoAppUserAccessScreenState();
}

class _FestenaoAppUserAccessScreenState
    extends State<FestenaoAppUserAccessScreen> {
  /// Live when the Firestore tracks changes; otherwise (the admin sdk and
  /// the rest apis have no `onSnapshot`) read again every few seconds, and
  /// right after every change made here.
  final _refresh = TrackChangesSupportOptionsController(
    refreshDelay: const Duration(seconds: 5),
  );

  late final _collection = festenaoAppUserAccessCollection(
    widget.appId,
  ).cast<TkCmsEditedFsUserAccess>();

  late final Stream<List<TkCmsEditedFsUserAccess>> _accesses = _collection
      .onSnapshotsSupport(widget.firestore, options: _refresh)
      .map(
        (accesses) =>
            accesses..sort((a, b) => _nameOf(a).compareTo(_nameOf(b))),
      );

  @override
  void initState() {
    initTkCmsFsUserAccessBuilders();
    super.initState();
  }

  @override
  void dispose() {
    _refresh.dispose();
    super.dispose();
  }

  String _nameOf(TkCmsEditedFsUserAccess access) => access.name.v ?? access.id;

  Future<void> _run(Future<void> Function() action, String done) async {
    var messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      _refresh.trigger();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  /// Grants ([TkCmsCvUserAccessCommonExt.grantAdminAccess]) or removes the
  /// admin access, the role following (`admin` or `user`).
  Future<void> _setAdmin(
    String userId, {
    required bool admin,
    String? name,
  }) async {
    var ref = _collection.doc(userId);
    var access = await ref.get(widget.firestore);
    if (name != null) {
      access.name.v = name;
    }
    if (admin) {
      access
        ..role.v = roleAdmin
        ..grantAdminAccess();
    } else {
      access
        ..role.v = roleUser
        ..admin.v = false
        ..write.v = false
        ..fixAccess();
    }
    await ref.set(widget.firestore, access);
  }

  Future<void> _add() async {
    var query = await showDialog<String>(
      context: context,
      builder: (context) => _AddUserDialog(byEmail: widget.auth != null),
    );
    if (query == null || query.trim().isEmpty || !mounted) {
      return;
    }
    await _run(() async {
      var auth = widget.auth;
      String userId;
      String? name;
      if (auth != null) {
        var entry = await FirebaseUsersExplorer(auth: auth).find(query);
        if (entry == null) {
          throw StateError('No user $query');
        }
        userId = entry.record.uid;
        name = entry.record.email ?? entry.record.displayName;
      } else {
        userId = query.trim();
      }
      await _setAdmin(userId, admin: true, name: name);
    }, '$query is an admin of ${widget.appId}');
  }

  Future<void> _revoke(TkCmsEditedFsUserAccess access) async {
    var name = _nameOf(access);
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove the access?'),
        content: Text('$name no longer has any access to ${widget.appId}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(
      () => _collection.doc(access.id).delete(widget.firestore),
      'Access of $name removed',
    );
  }

  @override
  Widget build(BuildContext context) {
    var auth = widget.auth;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Users of ${widget.appId}'),
        actions: [
          if (auth != null && auth.service.supportsListUsers)
            IconButton(
              tooltip: 'Firebase users',
              onPressed: () =>
                  goToFirebaseUsersExplorerScreen(context, auth: auth),
              icon: const Icon(Icons.people_outline),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add an admin'),
      ),
      body: StreamBuilder<List<TkCmsEditedFsUserAccess>>(
        stream: _accesses,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('${snapshot.error}'));
          }
          var accesses = snapshot.data;
          if (accesses == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (accesses.isEmpty) {
            return const Center(child: Text('No user has an access yet'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              for (var access in accesses)
                ListTile(
                  leading: Icon(
                    access.isAdmin
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline,
                  ),
                  title: Text(_nameOf(access)),
                  subtitle: Text('${access.id}  ·  ${_rightsOf(access)}'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      var name = _nameOf(access);
                      switch (action) {
                        case 'admin':
                          await _run(
                            () => _setAdmin(access.id, admin: true),
                            '$name is an admin',
                          );
                        case 'user':
                          await _run(
                            () => _setAdmin(access.id, admin: false),
                            '$name is no longer an admin',
                          );
                        case 'revoke':
                          await _revoke(access);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!access.isAdmin)
                        const PopupMenuItem(
                          value: 'admin',
                          child: Text('Make admin'),
                        ),
                      if (access.isAdmin)
                        const PopupMenuItem(
                          value: 'user',
                          child: Text('Remove admin'),
                        ),
                      const PopupMenuItem(
                        value: 'revoke',
                        child: Text('Remove the access'),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// `admin`, `write`, `read` or `no right`, with the role if any.
String _rightsOf(TkCmsFsUserAccess access) {
  var rights = access.isAdmin
      ? 'admin'
      : access.isWrite
      ? 'write'
      : access.isRead
      ? 'read'
      : 'no right';
  var role = access.role.v;
  return role == null ? rights : '$rights ($role)';
}

class _AddUserDialog extends StatefulWidget {
  final bool byEmail;

  const _AddUserDialog({required this.byEmail});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add an admin'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        labelText: widget.byEmail ? 'Email or user id' : 'User id',
        helperText: 'The account must exist (it is never created here)',
      ),
      onSubmitted: (value) => Navigator.of(context).pop(value),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Add'),
      ),
    ],
  );
}

/// Opens a [FestenaoAppUserAccessScreen].
Future<void> goToFestenaoAppUserAccessScreen(
  BuildContext context, {
  required Firestore firestore,
  required String appId,
  FirebaseAuth? auth,
  String? title,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FestenaoAppUserAccessScreen(
      firestore: firestore,
      appId: appId,
      auth: auth,
      title: title,
    ),
  ),
);
