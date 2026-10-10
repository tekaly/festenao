import 'package:festenao_common/admin/festenao_apps_admin.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firebase_auth.dart';
import 'package:festenao_common/firebase/firebase_users_explorer.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_user_access_flutter.dart';
import '../explorer_ui/explorer_chip.dart';
import '../explorer_ui/explorer_scaffold.dart';
import '../firebase_users_explorer_flutter.dart';

void _snack(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Runs [action] and says [done], or the error.
Future<bool> _run(
  BuildContext context,
  Future<void> Function() action,
  String done,
) async {
  try {
    await action();
    if (context.mounted) {
      _snack(context, done);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      _snack(context, '$e');
    }
    return false;
  }
}

/// The icon of an access granting [grant].
IconData _grantIcon(FestenaoUserAccessGrant? grant) => switch (grant) {
  FestenaoUserAccessGrant.superAdmin => Icons.verified_user_outlined,
  FestenaoUserAccessGrant.admin => Icons.admin_panel_settings_outlined,
  FestenaoUserAccessGrant.write => Icons.edit_outlined,
  FestenaoUserAccessGrant.read => Icons.visibility_outlined,
  null => Icons.block_outlined,
};

/// The chip of an access granting [grant].
Widget _grantChip(FestenaoUserAccessGrant? grant) => ExplorerChip(
  label: grant?.label ?? 'no right',
  tone: switch (grant) {
    FestenaoUserAccessGrant.superAdmin ||
    FestenaoUserAccessGrant.admin => ExplorerChipTone.accent,
    null => ExplorerChipTone.danger,
    _ => ExplorerChipTone.neutral,
  },
);

/// The menu changing an access: one entry per grant, then its removal
/// (`revoke`).
List<PopupMenuEntry<String>> _accessMenuItems(
  FestenaoUserAccessGrant? current,
) => [
  for (var grant in FestenaoUserAccessGrant.values.reversed)
    CheckedPopupMenuItem(
      value: grant.name,
      checked: grant == current,
      child: Text(grant.label),
    ),
  const PopupMenuDivider(),
  const PopupMenuItem(value: 'revoke', child: Text('Remove the access')),
];

/// The user found by [query] (an email or a user id) with [auth], the user id
/// itself without one.
Future<({String userId, String? email, String? name})> _findUser(
  FirebaseAuth? auth,
  String query,
) async {
  query = query.trim();
  if (auth == null) {
    return (userId: query, email: null, name: null);
  }
  var entry = await FirebaseUsersExplorer(auth: auth).find(query);
  if (entry == null) {
    throw StateError('No user $query');
  }
  return (
    userId: entry.uid,
    email: entry.email,
    name: entry.record.displayName,
  );
}

/// Every app of the firebase project of [admin]: its users (who is an admin,
/// a super admin...) and its projects and theirs.
///
/// ```dart
/// await goToAdminAppsScreen(
///   context,
///   admin: FestenaoAppsAdmin(firestore: context.firestore),
///   auth: context.auth,
/// );
/// ```
class AdminAppsScreen extends StatefulWidget {
  /// The apps and their access.
  final FestenaoAppsAdmin admin;

  /// The auth whose users are granted, to find them by email.
  final FirebaseAuth? auth;

  /// The title, the firebase project usually.
  final String title;

  /// Apps screen of [admin].
  const AdminAppsScreen({
    super.key,
    required this.admin,
    this.auth,
    this.title = 'Apps',
  });

  @override
  State<AdminAppsScreen> createState() => _AdminAppsScreenState();
}

class _AdminAppsScreenState extends State<AdminAppsScreen> {
  FestenaoAppsAdmin get admin => widget.admin;

  late Future<List<FestenaoAdminApp>> _loading = admin.apps();

  void _reload() => setState(() {
    _loading = admin.apps();
  });

  Future<void> _openUser() async {
    var query = await _promptText(
      context,
      title: 'Find a user',
      labelText: widget.auth == null ? 'User id' : 'Email or user id',
    );
    if (query == null || query.trim().isEmpty || !mounted) {
      return;
    }
    try {
      var user = await _findUser(widget.auth, query);
      if (!mounted) {
        return;
      }
      await goToAdminUserAccessScreen(
        context,
        admin: admin,
        userId: user.userId,
        email: user.email,
        name: user.name,
      );
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_search_outlined),
          tooltip: 'Find a user',
          onPressed: _openUser,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body: FutureBuilder<List<FestenaoAdminApp>>(
      future: _loading,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('${snapshot.error}'));
        }
        var apps = snapshot.data;
        if (apps == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            ExplorerSectionHeader(
              label: 'Apps',
              trailing: ExplorerChip(label: '${apps.length}'),
            ),
            if (apps.isEmpty)
              const ListTile(title: Text('No app in this project')),
            for (var app in apps)
              ListTile(
                leading: const Icon(Icons.apps_outlined),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(app.appId, overflow: TextOverflow.ellipsis),
                    ),
                    if (!app.exists) ...[
                      const SizedBox(width: 8),
                      const ExplorerChip(label: 'no document'),
                    ],
                  ],
                ),
                subtitle: app.name == null ? null : Text(app.name!),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => goToAdminAppScreen(
                  context,
                  admin: admin,
                  appId: app.appId,
                  auth: widget.auth,
                ),
              ),
            if (admin.listDocumentIds == null)
              const _Note(
                'Only the existing app documents are listed: this backend '
                'cannot list the ids that only hold access or projects '
                '(the admin sdk can).',
              ),
          ],
        );
      },
    ),
  );
}

/// One app: its users, and its projects with theirs.
class AdminAppScreen extends StatefulWidget {
  /// The apps and their access.
  final FestenaoAppsAdmin admin;

  /// The app.
  final String appId;

  /// The auth whose users are granted, to find them by email.
  final FirebaseAuth? auth;

  /// App screen of [appId].
  const AdminAppScreen({
    super.key,
    required this.admin,
    required this.appId,
    this.auth,
  });

  @override
  State<AdminAppScreen> createState() => _AdminAppScreenState();
}

class _AdminAppScreenState extends State<AdminAppScreen> {
  FestenaoAppsAdmin get admin => widget.admin;
  String get appId => widget.appId;

  late Future<(List<TkCmsEditedFsUserAccess>, List<FestenaoAdminProject>)>
  _loading = _load();

  Future<(List<TkCmsEditedFsUserAccess>, List<FestenaoAdminProject>)>
  _load() async => (
    await admin.userAccesses(admin.appAccess, appId),
    await admin.projects(appId),
  );

  void _reload() => setState(() {
    _loading = _load();
  });

  /// `2 users: 1 super admin, 1 admin`.
  static String _usersSummary(List<TkCmsEditedFsUserAccess> accesses) {
    var counts = <FestenaoUserAccessGrant?, int>{};
    for (var access in accesses) {
      var grant = FestenaoUserAccessGrant.of(access);
      counts[grant] = (counts[grant] ?? 0) + 1;
    }
    var details = [
      for (var grant in [...FestenaoUserAccessGrant.values.reversed, null])
        if (counts[grant] case var count?)
          '$count ${grant?.label ?? 'no right'}',
    ];
    var users = '${accesses.length} user${accesses.length == 1 ? '' : 's'}';
    return details.isEmpty ? users : '$users: ${details.join(', ')}';
  }

  Future<void> _openUsers({String? projectId, String? projectName}) async {
    await goToAdminEntityUserAccessScreen(
      context,
      admin: admin,
      entityAccess: projectId == null
          ? admin.appAccess
          : admin.projectAccess(appId),
      entityId: projectId ?? appId,
      title: projectId == null
          ? 'Users of $appId'
          : 'Users of ${projectName ?? projectId}',
      auth: widget.auth,
      defaultGrant: projectId == null
          ? FestenaoUserAccessGrant.admin
          : FestenaoUserAccessGrant.write,
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(appId),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    body:
        FutureBuilder<
          (List<TkCmsEditedFsUserAccess>, List<FestenaoAdminProject>)
        >(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('${snapshot.error}'));
            }
            var data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            var (accesses, projects) = data;
            return ListView(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Users'),
                  subtitle: Text(_usersSummary(accesses)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openUsers,
                ),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('Legacy app access'),
                  subtitle: Text('app/$appId/user_access'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => goToFestenaoAppUserAccessScreen(
                    context,
                    firestore: admin.firestore,
                    appId: appId,
                    auth: widget.auth,
                  ),
                ),
                ExplorerSectionHeader(
                  label: 'Projects',
                  trailing: ExplorerChip(label: '${projects.length}'),
                ),
                if (projects.isEmpty) const ListTile(title: Text('No project')),
                for (var project in projects)
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            project.name ?? project.projectId,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!project.exists) ...[
                          const SizedBox(width: 8),
                          const ExplorerChip(label: 'no document'),
                        ],
                      ],
                    ),
                    subtitle: project.name == null
                        ? null
                        : Text(project.projectId),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openUsers(
                      projectId: project.projectId,
                      projectName: project.name,
                    ),
                  ),
              ],
            );
          },
        ),
  );
}

/// The users having an access on one entity (an app, a project): change it
/// (read, write, admin, super admin), remove it, give one to another user.
///
/// Both sides of the tkcms entity access are written, see
/// [FestenaoAppsAdmin.setUserAccess].
class AdminEntityUserAccessScreen extends StatefulWidget {
  /// The apps and their access.
  final FestenaoAppsAdmin admin;

  /// The kind of entity: [FestenaoAppsAdmin.appAccess] or a
  /// [FestenaoAppsAdmin.projectAccess].
  final TkCmsFirestoreDatabaseServiceEntityAccess entityAccess;

  /// The entity.
  final String entityId;

  /// The auth whose users are granted, to find them by email.
  final FirebaseAuth? auth;

  /// The title, `Users of <entityId>` by default.
  final String? title;

  /// What a user added is given at first.
  final FestenaoUserAccessGrant defaultGrant;

  /// Access screen of [entityId].
  const AdminEntityUserAccessScreen({
    super.key,
    required this.admin,
    required this.entityAccess,
    required this.entityId,
    this.auth,
    this.title,
    this.defaultGrant = FestenaoUserAccessGrant.read,
  });

  @override
  State<AdminEntityUserAccessScreen> createState() =>
      _AdminEntityUserAccessScreenState();
}

class _AdminEntityUserAccessScreenState
    extends State<AdminEntityUserAccessScreen> {
  FestenaoAppsAdmin get admin => widget.admin;

  late Future<List<TkCmsEditedFsUserAccess>> _loading = _load();

  Future<List<TkCmsEditedFsUserAccess>> _load() =>
      admin.userAccesses(widget.entityAccess, widget.entityId);

  void _reload() => setState(() {
    _loading = _load();
  });

  Future<void> _set(
    String userId,
    String label,
    FestenaoUserAccessGrant? grant, {
    String? email,
    String? name,
  }) async {
    var done = await _run(
      context,
      () => admin.setUserAccess(
        widget.entityAccess,
        widget.entityId,
        userId,
        grant: grant,
        email: email,
        name: name,
      ),
      grant == null
          ? 'Access of $label removed'
          : '$label is ${grant.label} of ${widget.entityId}',
    );
    if (done && mounted) {
      _reload();
    }
  }

  Future<void> _revoke(TkCmsEditedFsUserAccess access) async {
    var label = festenaoAdminUserAccessLabel(access);
    var confirmed = await _confirm(
      context,
      title: 'Remove the access?',
      message: '$label no longer has any access to ${widget.entityId}.',
      confirmText: 'Remove',
    );
    if (confirmed && mounted) {
      await _set(access.id, label, null);
    }
  }

  Future<void> _add() async {
    var result = await showDialog<(String, FestenaoUserAccessGrant)>(
      context: context,
      builder: (_) => _GrantDialog(
        title: 'Give an access to ${widget.entityId}',
        labelText: widget.auth == null ? 'User id' : 'Email or user id',
        initialGrant: widget.defaultGrant,
      ),
    );
    if (result == null || result.$1.trim().isEmpty || !mounted) {
      return;
    }
    var (query, grant) = result;
    try {
      var user = await _findUser(widget.auth, query);
      if (!mounted) {
        return;
      }
      await _set(
        user.userId,
        user.email ?? user.userId,
        grant,
        email: user.email,
        name: user.name,
      );
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title ?? 'Users of ${widget.entityId}'),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Add a user'),
    ),
    body: FutureBuilder<List<TkCmsEditedFsUserAccess>>(
      future: _loading,
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
          children: [for (var access in accesses) _buildTile(access)],
        );
      },
    ),
  );

  Widget _buildTile(TkCmsEditedFsUserAccess access) {
    var grant = FestenaoUserAccessGrant.of(access);
    var label = festenaoAdminUserAccessLabel(access);
    var subtitle = [
      if (access.email.v case var email? when email != label) email,
      if (access.id != label) access.id,
    ].join(' · ');
    return ListTile(
      leading: Icon(_grantIcon(grant)),
      title: Row(
        children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          _grantChip(grant),
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        itemBuilder: (_) => _accessMenuItems(grant),
        onSelected: (action) => action == 'revoke'
            ? _revoke(access)
            : _set(
                access.id,
                label,
                FestenaoUserAccessGrant.values.byName(action),
              ),
      ),
      onTap: () async {
        await goToAdminUserAccessScreen(
          context,
          admin: admin,
          userId: access.id,
          email: access.email.v,
          name: access.name.v,
        );
        _reload();
      },
    );
  }
}

/// Every access of one user: to the apps and to their projects, changed or
/// removed in place, and an app access given.
class AdminUserAccessScreen extends StatefulWidget {
  /// The apps and their access.
  final FestenaoAppsAdmin admin;

  /// The user.
  final String userId;

  /// Their email, kept in the access given here.
  final String? email;

  /// Their name, kept in the access given here.
  final String? name;

  /// Access screen of [userId].
  const AdminUserAccessScreen({
    super.key,
    required this.admin,
    required this.userId,
    this.email,
    this.name,
  });

  @override
  State<AdminUserAccessScreen> createState() => _AdminUserAccessScreenState();
}

class _AdminUserAccessScreenState extends State<AdminUserAccessScreen> {
  FestenaoAppsAdmin get admin => widget.admin;
  String get userId => widget.userId;
  String get _label => widget.email ?? widget.name ?? userId;

  late Future<(List<FestenaoAdminApp>, List<FestenaoAdminUserEntityAccess>)>
  _loading = _load();

  Future<(List<FestenaoAdminApp>, List<FestenaoAdminUserEntityAccess>)>
  _load() async {
    var apps = await admin.apps();
    var accesses = await admin.userEntityAccesses(
      userId,
      appIds: apps.map((app) => app.appId).toList(),
    );
    return (apps, accesses);
  }

  void _reload() => setState(() {
    _loading = _load();
  });

  TkCmsFirestoreDatabaseServiceEntityAccess _entityAccessOf(
    String appId,
    String? projectId,
  ) => projectId == null ? admin.appAccess : admin.projectAccess(appId);

  Future<void> _set(
    String appId,
    String? projectId,
    FestenaoUserAccessGrant? grant,
  ) async {
    var entityId = projectId ?? appId;
    var done = await _run(
      context,
      () => admin.setUserAccess(
        _entityAccessOf(appId, projectId),
        entityId,
        userId,
        grant: grant,
        email: widget.email,
        name: widget.name,
      ),
      grant == null
          ? 'Access to $entityId removed'
          : '$_label is ${grant.label} of $entityId',
    );
    if (done && mounted) {
      _reload();
    }
  }

  Future<void> _revoke(FestenaoAdminUserEntityAccess access) async {
    var confirmed = await _confirm(
      context,
      title: 'Remove the access?',
      message: '$_label no longer has any access to ${access.entityId}.',
      confirmText: 'Remove',
    );
    if (confirmed && mounted) {
      await _set(access.appId, access.projectId, null);
    }
  }

  Future<void> _grantApp(List<FestenaoAdminApp> apps) async {
    if (apps.isEmpty) {
      _snack(context, 'No app in this project');
      return;
    }
    var result = await showDialog<(String, FestenaoUserAccessGrant)>(
      context: context,
      builder: (_) => _GrantDialog(
        title: 'Give $_label an app access',
        appIds: apps.map((app) => app.appId).toList(),
        initialGrant: FestenaoUserAccessGrant.admin,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    await _set(result.$1, null, result.$2);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<
        (List<FestenaoAdminApp>, List<FestenaoAdminUserEntityAccess>)
      >(
        future: _loading,
        builder: (context, snapshot) {
          var data = snapshot.data;
          return Scaffold(
            appBar: AppBar(
              title: Text(_label),
              actions: [
                IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copy the user id',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: userId));
                    if (context.mounted) {
                      _snack(context, 'Copied $userId');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reload',
                  onPressed: _reload,
                ),
              ],
            ),
            floatingActionButton: data == null
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _grantApp(data.$1),
                    icon: const Icon(Icons.add_moderator_outlined),
                    label: const Text('Give an app access'),
                  ),
            body: _buildBody(snapshot),
          );
        },
      );

  Widget _buildBody(
    AsyncSnapshot<(List<FestenaoAdminApp>, List<FestenaoAdminUserEntityAccess>)>
    snapshot,
  ) {
    if (snapshot.hasError) {
      return Center(child: Text('${snapshot.error}'));
    }
    var data = snapshot.data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    var (_, accesses) = data;
    var appAccesses = accesses.where((a) => a.projectId == null).toList();
    var projectAccesses = accesses.where((a) => a.projectId != null).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.person_outline),
          title: SelectableText(userId),
          subtitle: widget.name == null || widget.name == _label
              ? null
              : Text(widget.name!),
        ),
        ExplorerSectionHeader(
          label: 'Apps',
          trailing: ExplorerChip(label: '${appAccesses.length}'),
        ),
        if (appAccesses.isEmpty) const ListTile(title: Text('No app access')),
        for (var access in appAccesses) _buildTile(access),
        ExplorerSectionHeader(
          label: 'Projects',
          trailing: ExplorerChip(label: '${projectAccesses.length}'),
        ),
        if (projectAccesses.isEmpty)
          const ListTile(title: Text('No project access')),
        for (var access in projectAccesses) _buildTile(access),
      ],
    );
  }

  Widget _buildTile(FestenaoAdminUserEntityAccess access) {
    var grant = FestenaoUserAccessGrant.of(access.access);
    return ListTile(
      leading: Icon(_grantIcon(grant)),
      title: Row(
        children: [
          Flexible(
            child: Text(access.entityId, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          _grantChip(grant),
        ],
      ),
      subtitle: access.projectId == null ? null : Text(access.appId),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        itemBuilder: (_) => _accessMenuItems(grant),
        onSelected: (action) => action == 'revoke'
            ? _revoke(access)
            : _set(
                access.appId,
                access.projectId,
                FestenaoUserAccessGrant.values.byName(action),
              ),
      ),
    );
  }
}

/// Asks for a user (an email or a user id) or, with [appIds], an app, and
/// the access to give; answers both.
class _GrantDialog extends StatefulWidget {
  final String title;
  final String? labelText;
  final List<String>? appIds;
  final FestenaoUserAccessGrant initialGrant;

  const _GrantDialog({
    required this.title,
    this.labelText,
    this.appIds,
    required this.initialGrant,
  });

  @override
  State<_GrantDialog> createState() => _GrantDialogState();
}

class _GrantDialogState extends State<_GrantDialog> {
  final _controller = TextEditingController();
  late var _grant = widget.initialGrant;
  late String? _appId = widget.appIds?.firstOrNull;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    var value = widget.appIds == null ? _controller.text : _appId;
    if (value == null) {
      return;
    }
    Navigator.of(context).pop((value, _grant));
  }

  @override
  Widget build(BuildContext context) {
    var appIds = widget.appIds;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (appIds == null)
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: widget.labelText,
                helperText: 'The account must exist (it is never created here)',
              ),
              onSubmitted: (_) => _submit(),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _appId,
              decoration: const InputDecoration(labelText: 'App'),
              items: [
                for (var appId in appIds)
                  DropdownMenuItem(value: appId, child: Text(appId)),
              ],
              onChanged: (value) => setState(() => _appId = value),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<FestenaoUserAccessGrant>(
            initialValue: _grant,
            decoration: const InputDecoration(labelText: 'Access'),
            items: [
              for (var grant in FestenaoUserAccessGrant.values.reversed)
                DropdownMenuItem(value: grant, child: Text(grant.label)),
            ],
            onChanged: (value) => setState(() => _grant = value ?? _grant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Give')),
      ],
    );
  }
}

Future<String?> _promptText(
  BuildContext context, {
  required String title,
  required String labelText,
}) {
  var controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: labelText),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Find'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ??
    false;

class _Note extends StatelessWidget {
  final String text;

  const _Note(this.text);

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Pushes an [AdminAppsScreen].
Future<void> goToAdminAppsScreen(
  BuildContext context, {
  required FestenaoAppsAdmin admin,
  FirebaseAuth? auth,
  String title = 'Apps',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminAppsScreen(admin: admin, auth: auth, title: title),
  ),
);

/// Pushes an [AdminAppScreen].
Future<void> goToAdminAppScreen(
  BuildContext context, {
  required FestenaoAppsAdmin admin,
  required String appId,
  FirebaseAuth? auth,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminAppScreen(admin: admin, appId: appId, auth: auth),
  ),
);

/// Pushes an [AdminEntityUserAccessScreen].
Future<void> goToAdminEntityUserAccessScreen(
  BuildContext context, {
  required FestenaoAppsAdmin admin,
  required TkCmsFirestoreDatabaseServiceEntityAccess entityAccess,
  required String entityId,
  FirebaseAuth? auth,
  String? title,
  FestenaoUserAccessGrant defaultGrant = FestenaoUserAccessGrant.read,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminEntityUserAccessScreen(
      admin: admin,
      entityAccess: entityAccess,
      entityId: entityId,
      auth: auth,
      title: title,
      defaultGrant: defaultGrant,
    ),
  ),
);

/// Pushes an [AdminUserAccessScreen].
Future<void> goToAdminUserAccessScreen(
  BuildContext context, {
  required FestenaoAppsAdmin admin,
  required String userId,
  String? email,
  String? name,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => AdminUserAccessScreen(
      admin: admin,
      userId: userId,
      email: email,
      name: name,
    ),
  ),
);

/// The users explorer action opening the [AdminUserAccessScreen] of a user.
FirebaseUserAction adminUserAccessAction({required FestenaoAppsAdmin admin}) =>
    FirebaseUserAction(
      label: 'Access to the apps',
      icon: Icons.admin_panel_settings_outlined,
      onSelected: (context, user) => goToAdminUserAccessScreen(
        context,
        admin: admin,
        userId: user.uid,
        email: user.email,
        name: user.record.displayName,
      ),
    );
