import 'package:festenao_common/firebase/firebase_auth.dart';
import 'package:festenao_common/firebase/firebase_users_explorer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'object_editor/object_editor_dialogs.dart';

/// The icon a user is listed with: disabled, anonymous or a plain one.
IconData firebaseUserEntryIcon(FirebaseUserEntry user) => user.isDisabled
    ? Icons.person_off_outlined
    : user.isAnonymous
    ? Icons.no_accounts_outlined
    : Icons.person_outline;

/// The chips marking what is worth noticing about a user: anonymous,
/// disabled, an email not verified yet.
List<Widget> firebaseUserEntryChips(FirebaseUserEntry user) => [
  if (user.isAnonymous)
    const ExplorerChip(label: 'anonymous', tone: ExplorerChipTone.accent),
  if (user.isDisabled)
    const ExplorerChip(label: 'disabled', tone: ExplorerChipTone.danger),
  if (user.email != null && !user.emailVerified)
    const ExplorerChip(label: 'unverified'),
];

void _snack(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _copyUid(BuildContext context, String uid) async {
  await Clipboard.setData(ClipboardData(text: uid));
  if (context.mounted) {
    _snack(context, 'Copied $uid');
  }
}

/// A screen browsing the users of a [FirebaseUsersExplorer].
///
/// It lists them page by page when the backend can, and finds one by uid or
/// email either way — the rest api with a service account cannot list its
/// users, but still answers by uid. Tapping one shows all its backend
/// reports, see [FirebaseUserScreen].
///
/// An admin auth (`FirebaseAuthAdmin`, the admin sdk or the local sdb one)
/// also creates and deletes users, unless the explorer is read only.
///
/// ```dart
/// await goToFirebaseUsersExplorerScreen(context, auth: auth);
/// ```
class FirebaseUsersExplorerScreen extends StatefulWidget {
  /// The users being browsed.
  final FirebaseUsersExplorer explorer;

  /// The title of the screen, the project the users belong to.
  final String title;

  /// Explorer of the users of [explorer].
  const FirebaseUsersExplorerScreen({
    super.key,
    required this.explorer,
    this.title = 'Users',
  });

  @override
  State<FirebaseUsersExplorerScreen> createState() =>
      _FirebaseUsersExplorerScreenState();
}

class _FirebaseUsersExplorerScreenState
    extends State<FirebaseUsersExplorerScreen> {
  FirebaseUsersExplorer get explorer => widget.explorer;

  final _users = <FirebaseUserEntry>[];
  String? _nextPageToken;
  Object? _error;
  var _isLoading = false;

  /// Bumped on each reload, so a page loaded before it is dropped.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (!explorer.canList) {
      return;
    }
    setState(() {
      _generation++;
      _users.clear();
      _nextPageToken = null;
      _error = null;
    });
    _loadPage(null);
  }

  Future<void> _loadPage(String? pageToken) async {
    var generation = _generation;
    setState(() => _isLoading = true);
    try {
      var page = await explorer.list(pageToken: pageToken);
      if (mounted && generation == _generation) {
        setState(() {
          _users.addAll(page.users);
          _nextPageToken = page.nextPageToken;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _open(FirebaseUserEntry user) async {
    await goToFirebaseUserScreen(
      context,
      explorer: explorer,
      user: user,
      title: widget.title,
    );
    _reload();
  }

  Future<void> _find() async {
    var query = await objectEditorPromptText(
      context,
      title: 'Find a user',
      labelText: 'Uid or email',
    );
    if (query == null || query.trim().isEmpty || !mounted) {
      return;
    }
    FirebaseUserEntry? user;
    try {
      user = await explorer.find(query);
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    if (user == null) {
      _snack(context, 'No user ${query.trim()}');
      return;
    }
    await _open(user);
  }

  Future<void> _create() async {
    var request = await showDialog<FirebaseAuthCreateUserRequest>(
      context: context,
      builder: (_) => const FirebaseUserCreateDialog(),
    );
    if (request == null || !mounted) {
      return;
    }
    FirebaseUserEntry user;
    try {
      user = await explorer.create(request);
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
      return;
    }
    if (mounted) {
      await _open(user);
    }
  }

  Future<void> _delete(FirebaseUserEntry user) async {
    if (await confirmFirebaseUserDelete(context, explorer, user)) {
      _reload();
    }
  }

  Widget _buildTile(FirebaseUserEntry user) {
    var subtitle = [
      if (user.email case var email? when email != user.label) email,
      if (user.uid != user.label) user.uid,
    ].join(' · ');
    return ListTile(
      leading: Icon(firebaseUserEntryIcon(user)),
      title: Row(
        children: [
          Flexible(child: Text(user.label, overflow: TextOverflow.ellipsis)),
          for (var chip in firebaseUserEntryChips(user)) ...[
            const SizedBox(width: 8),
            chip,
          ],
        ],
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'copy_uid', child: Text('Copy uid')),
          if (explorer.canWrite)
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
        onSelected: (action) => switch (action) {
          'copy_uid' => _copyUid(context, user.uid),
          'delete' => _delete(user),
          _ => null,
        },
      ),
      onTap: () => _open(user),
    );
  }

  Widget _buildBody() {
    if (!explorer.canList) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search_outlined, size: 48),
              const SizedBox(height: 12),
              const Text(
                'This auth cannot list its users, '
                'find one by its uid or email',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _find,
                icon: const Icon(Icons.search),
                label: const Text('Find a user'),
              ),
            ],
          ),
        ),
      );
    }
    if (_users.isEmpty) {
      if (_error != null) {
        return Center(child: Text('$_error'));
      }
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('No user'));
    }
    var hasMore = _nextPageToken != null;
    return ListView.builder(
      itemCount: _users.length + (hasMore ? 2 : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ExplorerSectionHeader(
            label: 'Users',
            trailing: ExplorerChip(
              label: '${_users.length}${hasMore ? '+' : ''}',
            ),
          );
        }
        if (index > _users.length) {
          return _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : ListTile(
                  leading: const Icon(Icons.expand_more),
                  title: const Text('Load more'),
                  onTap: () => _loadPage(_nextPageToken),
                );
        }
        return _buildTile(_users[index - 1]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.title,
    isReadOnly: explorer.isReadOnly,
    crumbs: [ExplorerCrumb(widget.title), const ExplorerCrumb('users')],
    stateChip: ExplorerChip(
      label: explorer.canList ? 'listed' : 'lookup only',
      icon: Icons.people_outline,
      tone: ExplorerChipTone.accent,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.person_search_outlined),
        tooltip: 'Find a user',
        onPressed: _find,
      ),
      if (explorer.canList)
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Reload',
          onPressed: _reload,
        ),
    ],
    statusBar: ExplorerStatusBar(
      message: widget.title,
      trailing: [
        if (explorer.canList)
          ExplorerChip(
            label: '${_users.length}${_nextPageToken != null ? '+' : ''} users',
          ),
        if (explorer.canWrite) const ExplorerChip(label: 'admin'),
      ],
    ),
    body: _buildBody(),
    floatingActionButton: explorer.canWrite
        ? FloatingActionButton(
            tooltip: 'New user',
            onPressed: _create,
            child: const Icon(Icons.person_add_outlined),
          )
        : null,
  );
}

/// Asks before deleting [user], and deletes it: true when it is gone.
Future<bool> confirmFirebaseUserDelete(
  BuildContext context,
  FirebaseUsersExplorer explorer,
  FirebaseUserEntry user,
) async {
  var confirmed = await objectEditorPromptConfirm(
    context,
    title: 'Delete ${user.label}',
    message: 'Delete the user ${user.uid}? It will not sign in any more.',
    confirmText: 'Delete',
  );
  if (!confirmed) {
    return false;
  }
  try {
    await explorer.delete(user.uid);
    return true;
  } catch (e) {
    if (context.mounted) {
      _snack(context, '$e');
    }
    return false;
  }
}

/// A screen showing one user: every field its backend reports.
class FirebaseUserScreen extends StatefulWidget {
  /// The explorer the user was found with.
  final FirebaseUsersExplorer explorer;

  /// The user, as it was listed.
  final FirebaseUserEntry user;

  /// The title of the users screen, the first step of the path.
  final String title;

  /// Screen of [user].
  const FirebaseUserScreen({
    super.key,
    required this.explorer,
    required this.user,
    this.title = 'Users',
  });

  @override
  State<FirebaseUserScreen> createState() => _FirebaseUserScreenState();
}

class _FirebaseUserScreenState extends State<FirebaseUserScreen> {
  FirebaseUsersExplorer get explorer => widget.explorer;

  String get _uid => widget.user.uid;

  /// The user as last read, null once it is gone.
  late Future<FirebaseUserEntry?> _loading = Future.value(widget.user);

  void _reload() => setState(() {
    _loading = explorer.get(_uid);
  });

  Future<void> _delete(FirebaseUserEntry user) async {
    if (await confirmFirebaseUserDelete(context, explorer, user) && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// A value as the screen shows it.
  static String _format(Object? value) => switch (value) {
    List<Object?> list => list.join(', '),
    _ => '$value',
  };

  Widget _buildBody(FirebaseUserEntry user) {
    var theme = Theme.of(context);
    var chips = firebaseUserEntryChips(user);
    return ListView(
      children: [
        if (chips.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(spacing: 6, runSpacing: 6, children: chips),
          ),
        ExplorerSectionHeader(
          label: 'Fields',
          trailing: ExplorerChip(label: '${user.fields.length}'),
        ),
        for (var MapEntry(:key, :value) in user.fields.entries)
          ListTile(
            dense: true,
            title: Text(key, style: theme.textTheme.labelMedium),
            subtitle: SelectableText(
              _format(value),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Only the fields this auth backend reports are shown.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<FirebaseUserEntry?>(
    future: _loading,
    builder: (context, snapshot) {
      var user = snapshot.data;
      var isGone =
          snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError &&
          user == null;
      return ExplorerScaffold(
        title: user?.label ?? widget.user.label,
        isReadOnly: explorer.isReadOnly,
        crumbs: [
          ExplorerCrumb(widget.title),
          ExplorerCrumb('users', onTap: () => Navigator.of(context).pop()),
          ExplorerCrumb(_uid),
        ],
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy uid',
            onPressed: () => _copyUid(context, _uid),
          ),
          if (explorer.canWrite && user != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _delete(user),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
            onPressed: _reload,
          ),
        ],
        statusBar: ExplorerStatusBar(
          message: _uid,
          trailing: [if (user != null) ExplorerChip(label: user.label)],
        ),
        body: snapshot.hasError
            ? Center(child: Text('${snapshot.error}'))
            : isGone
            ? Center(child: Text('No user $_uid'))
            : user == null
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(user),
      );
    },
  );
}

/// A dialog answering the user to create, null when cancelled.
///
/// The uid is generated when left empty; the password is what an email user
/// signs in with.
class FirebaseUserCreateDialog extends StatefulWidget {
  /// Const constructor.
  const FirebaseUserCreateDialog({super.key});

  @override
  State<FirebaseUserCreateDialog> createState() =>
      _FirebaseUserCreateDialogState();
}

class _FirebaseUserCreateDialogState extends State<FirebaseUserCreateDialog> {
  final _uid = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  var _emailVerified = false;
  var _disabled = false;

  @override
  void dispose() {
    for (var controller in [_uid, _email, _password, _displayName]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _text(TextEditingController controller) {
    var text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _submit() {
    Navigator.of(context).pop(
      FirebaseAuthCreateUserRequest(
        uid: _text(_uid),
        email: _text(_email),
        password: _text(_password),
        displayName: _text(_displayName),
        emailVerified: _emailVerified,
        disabled: _disabled,
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    bool autofocus = false,
  }) => TextField(
    controller: controller,
    autofocus: autofocus,
    obscureText: obscure,
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New user'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_email, 'Email', autofocus: true),
          _field(_password, 'Password', obscure: true),
          _field(_displayName, 'Display name'),
          _field(_uid, 'Uid (empty for a generated one)'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Email verified'),
            value: _emailVerified,
            onChanged: (value) => setState(() => _emailVerified = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Disabled'),
            value: _disabled,
            onChanged: (value) => setState(() => _disabled = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _submit, child: const Text('Create')),
    ],
  );
}

/// Pushes a [FirebaseUsersExplorerScreen] on the users of [auth].
Future<void> goToFirebaseUsersExplorerScreen(
  BuildContext context, {
  required FirebaseAuth auth,
  bool isReadOnly = false,
  String title = 'Users',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FirebaseUsersExplorerScreen(
      explorer: FirebaseUsersExplorer(auth: auth, isReadOnly: isReadOnly),
      title: title,
    ),
  ),
);

/// Pushes a [FirebaseUserScreen] on [user].
Future<void> goToFirebaseUserScreen(
  BuildContext context, {
  required FirebaseUsersExplorer explorer,
  required FirebaseUserEntry user,
  String title = 'Users',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) =>
        FirebaseUserScreen(explorer: explorer, user: user, title: title),
  ),
);
