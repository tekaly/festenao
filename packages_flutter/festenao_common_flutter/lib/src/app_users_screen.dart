import 'package:festenao_common/api/festenao_app_user.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'explorer_ui/explorer_chip.dart';
import 'explorer_ui/explorer_scaffold.dart';
import 'object_editor/object_editor_dialogs.dart';

void _snack(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '?';
  }
  var text = dateTime.toLocal().toIso8601String();
  return text.substring(0, 16).replaceFirst('T', ' ');
}

/// Which users the screen lists.
enum _AppUsersFilter { all, anonymous, accounts }

/// A screen browsing the users of an app ([TkCmsAppUsers]): when each one was
/// last seen, sorted, filtered, searched by email, and their purge.
///
/// [appUsers] is the api implementation for an app admin of a client app,
/// the firestore one in an admin build (admin sdk).
///
/// ```dart
/// await goToAppUsersScreen(
///   context,
///   appUsers: TkCmsAppUsersApi(apiService: apiService),
/// );
/// ```
class AppUsersScreen extends StatefulWidget {
  /// The users of the app.
  final TkCmsAppUsers appUsers;

  /// The title, the app the users belong to.
  final String title;

  /// Screen of [appUsers].
  const AppUsersScreen({
    super.key,
    required this.appUsers,
    this.title = 'App users',
  });

  @override
  State<AppUsersScreen> createState() => _AppUsersScreenState();
}

class _AppUsersScreenState extends State<AppUsersScreen> {
  TkCmsAppUsers get appUsers => widget.appUsers;

  final _users = <ApiAppUser>[];
  String? _nextStartAfterUserId;
  Object? _error;
  var _isLoading = false;
  var _filter = _AppUsersFilter.all;
  var _orderBy = tkCmsAppUserOrderByLastSeen;
  String? _emailPrefix;

  /// Bumped on each reload, so a page loaded before it is dropped.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  ApiAppUserListQuery _query(String? startAfterUserId) => ApiAppUserListQuery()
    ..orderBy.v = _orderBy
    ..anonymous.v = switch (_filter) {
      _AppUsersFilter.all => null,
      _AppUsersFilter.anonymous => true,
      _AppUsersFilter.accounts => false,
    }
    ..emailPrefix.v = _emailPrefix
    ..limit.v = 50
    ..startAfterUserId.v = startAfterUserId;

  void _reload() {
    setState(() {
      _generation++;
      _users.clear();
      _nextStartAfterUserId = null;
      _error = null;
    });
    _loadPage(null);
  }

  Future<void> _loadPage(String? startAfterUserId) async {
    var generation = _generation;
    setState(() => _isLoading = true);
    try {
      var page = await appUsers.list(_query(startAfterUserId));
      if (mounted && generation == _generation) {
        setState(() {
          _users.addAll(page.users.v ?? const []);
          _nextStartAfterUserId = page.nextStartAfterUserId.v;
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

  Future<void> _searchEmail() async {
    var prefix = await objectEditorPromptText(
      context,
      title: 'Users whose email starts with',
      labelText: 'Email prefix (empty for all)',
      initialValue: _emailPrefix,
    );
    if (prefix == null || !mounted) {
      return;
    }
    var trimmed = prefix.trim();
    _emailPrefix = trimmed.isEmpty ? null : trimmed;
    _reload();
  }

  Future<void> _find() async {
    var userId = await objectEditorPromptText(
      context,
      title: 'Find a user',
      labelText: 'User id',
    );
    if (userId == null || userId.trim().isEmpty || !mounted) {
      return;
    }
    await _showDetails(userId.trim());
  }

  Future<void> _showDetails(String userId) async {
    ApiAppUserGetResult result;
    try {
      result = await appUsers.get(userId);
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    var user = result.user.v;
    var lines = <(String, String?)>[
      ('User id', userId),
      if (user != null) ...[
        ('Name', user.name.v),
        ('Email', user.email.v),
        ('Anonymous', user.anonymous.v?.toString()),
        ('Last seen', _formatDateTime(user.lastSeenDateTime)),
        ('Created', _formatDateTime(user.createdDateTime)),
        ('App version', user.appVersion.v),
        ('Platform', user.platform.v),
      ] else
        ('App', 'never seen by this app'),
      (
        'Auth user',
        switch (result.authExists.v) {
          true => 'exists',
          false => 'missing',
          null => 'unknown',
        },
      ),
      if (result.authAnonymous.v != null)
        ('Auth anonymous', result.authAnonymous.v.toString()),
      if (result.authDisabled.v == true) ('Auth disabled', 'true'),
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user?.label ?? userId),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var (label, value) in lines)
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SelectableText('$label: $value'),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Purges [query] users: a dry run first, then the users it listed once
  /// confirmed.
  Future<void> _purge(
    ApiAppUserPurgeQuery query, {
    required String what,
  }) async {
    ApiAppUserPurgeResult dryRun;
    try {
      dryRun = await appUsers.purge(query..dryRun.v = true);
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    var userIds = dryRun.purgedIds.v ?? const <String>[];
    var skipped = dryRun.skippedIds.v ?? const <String>[];
    if (userIds.isEmpty) {
      _snack(
        context,
        'No user to purge${skipped.isEmpty ? '' : ', ${skipped.length} kept'}',
      );
      return;
    }
    var sample = userIds.take(10).join('\n');
    var confirmed = await objectEditorPromptConfirm(
      context,
      title: 'Purge ${userIds.length} $what',
      message:
          'Their data, their auth user (unless another app uses it) and their '
          'document are deleted.\n\n$sample'
          '${userIds.length > 10 ? '\n...' : ''}'
          '${skipped.isEmpty ? '' : '\n\n${skipped.length} kept (linked since).'}',
      confirmText: 'Purge',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      var result = await appUsers.purge(
        ApiAppUserPurgeQuery()
          ..userIds.v = userIds
          ..anonymousOnly.v = query.anonymousOnly.v
          ..dryRun.v = false,
      );
      if (mounted) {
        var errors = result.errors.v ?? const [];
        _snack(
          context,
          'Purged ${result.purgedIds.v?.length ?? 0}'
          '${errors.isEmpty ? '' : ', ${errors.length} errors: ${errors.first}'}',
        );
      }
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
      }
    }
    _reload();
  }

  Future<void> _purgeNotSeenSince({required bool anonymousOnly}) async {
    var daysText = await objectEditorPromptText(
      context,
      title: anonymousOnly
          ? 'Purge the anonymous users not seen for'
          : 'Purge the users (accounts too) not seen for',
      labelText: 'Days',
      initialValue: '365',
    );
    var days = int.tryParse(daysText?.trim() ?? '');
    if (days == null || days < 1 || !mounted) {
      return;
    }
    await _purge(
      ApiAppUserPurgeQuery()
        ..seenBefore.v = DateTime.now()
            .toUtc()
            .subtract(Duration(days: days))
            .toIso8601String()
        ..anonymousOnly.v = anonymousOnly
        ..limit.v = 500,
      what: anonymousOnly ? 'anonymous users' : 'users',
    );
  }

  Widget _buildTile(ApiAppUser user) {
    var userId = user.userId.v ?? '';
    var subtitle = [
      if (user.email.v case var email? when email != user.label) email,
      if (userId != user.label) userId,
      'seen ${_formatDateTime(user.lastSeenDateTime)}',
      if (user.appVersion.v case var version?) 'v$version',
    ].join(' · ');
    var anonymous = user.anonymous.v ?? false;
    return ListTile(
      leading: Icon(
        anonymous ? Icons.no_accounts_outlined : Icons.person_outline,
      ),
      title: Row(
        children: [
          Flexible(child: Text(user.label, overflow: TextOverflow.ellipsis)),
          if (anonymous) ...[
            const SizedBox(width: 8),
            const ExplorerChip(
              label: 'anonymous',
              tone: ExplorerChipTone.accent,
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 20),
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'details', child: Text('Details')),
          PopupMenuItem(value: 'copy_uid', child: Text('Copy user id')),
          PopupMenuItem(value: 'purge', child: Text('Purge')),
        ],
        onSelected: (action) async {
          switch (action) {
            case 'details':
              await _showDetails(userId);
            case 'copy_uid':
              await Clipboard.setData(ClipboardData(text: userId));
              if (mounted) {
                _snack(context, 'Copied $userId');
              }
            case 'purge':
              await _purge(
                ApiAppUserPurgeQuery()
                  ..userIds.v = [userId]
                  ..anonymousOnly.v = false,
                what: 'user',
              );
          }
        },
      ),
      onTap: () => _showDetails(userId),
    );
  }

  Widget _buildBody() {
    if (_users.isEmpty) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$_error', textAlign: TextAlign.center),
          ),
        );
      }
      if (_isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Center(child: Text('No user'));
    }
    var hasMore = _nextStartAfterUserId != null;
    return ListView.builder(
      itemCount: _users.length + (hasMore ? 2 : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return ExplorerSectionHeader(
            label: [
              switch (_filter) {
                _AppUsersFilter.all => 'Users',
                _AppUsersFilter.anonymous => 'Anonymous users',
                _AppUsersFilter.accounts => 'Accounts',
              },
              if (_emailPrefix case var prefix?) 'email $prefix…',
            ].join(' · '),
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
                  onTap: () => _loadPage(_nextStartAfterUserId),
                );
        }
        return _buildTile(_users[index - 1]);
      },
    );
  }

  @override
  Widget build(BuildContext context) => ExplorerScaffold(
    title: widget.title,
    crumbs: [ExplorerCrumb(widget.title), const ExplorerCrumb('app users')],
    stateChip: ExplorerChip(
      label: _emailPrefix != null
          ? 'by email'
          : _orderBy == tkCmsAppUserOrderByCreated
          ? 'newest created'
          : 'last seen',
      icon: Icons.people_outline,
      tone: ExplorerChipTone.accent,
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.person_search_outlined),
        tooltip: 'Find a user',
        onPressed: _find,
      ),
      IconButton(
        icon: const Icon(Icons.alternate_email),
        tooltip: 'Search by email',
        onPressed: _searchEmail,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.filter_list),
        tooltip: 'Filter and sort',
        itemBuilder: (context) => [
          for (var filter in _AppUsersFilter.values)
            CheckedPopupMenuItem(
              value: 'filter_${filter.name}',
              checked: _filter == filter,
              child: Text(switch (filter) {
                _AppUsersFilter.all => 'All users',
                _AppUsersFilter.anonymous => 'Anonymous users',
                _AppUsersFilter.accounts => 'Accounts',
              }),
            ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            value: 'order_$tkCmsAppUserOrderByLastSeen',
            checked: _orderBy == tkCmsAppUserOrderByLastSeen,
            child: const Text('Last seen first'),
          ),
          CheckedPopupMenuItem(
            value: 'order_$tkCmsAppUserOrderByCreated',
            checked: _orderBy == tkCmsAppUserOrderByCreated,
            child: const Text('Newest first'),
          ),
        ],
        onSelected: (value) {
          if (value.startsWith('filter_')) {
            _filter = _AppUsersFilter.values.byName(
              value.substring('filter_'.length),
            );
          } else if (value.startsWith('order_')) {
            _orderBy = value.substring('order_'.length);
          }
          _reload();
        },
      ),
      IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Reload',
        onPressed: _reload,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.delete_sweep_outlined),
        tooltip: 'Purge',
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'anonymous',
            child: Text('Purge anonymous users not seen since…'),
          ),
          PopupMenuItem(
            value: 'all',
            child: Text('Purge users (accounts too) not seen since…'),
          ),
        ],
        onSelected: (value) =>
            _purgeNotSeenSince(anonymousOnly: value == 'anonymous'),
      ),
    ],
    statusBar: ExplorerStatusBar(
      message: widget.title,
      trailing: [
        ExplorerChip(
          label:
              '${_users.length}${_nextStartAfterUserId != null ? '+' : ''} users',
        ),
      ],
    ),
    body: _buildBody(),
  );
}

/// Opens the [AppUsersScreen] of [appUsers].
Future<void> goToAppUsersScreen(
  BuildContext context, {
  required TkCmsAppUsers appUsers,
  String title = 'App users',
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AppUsersScreen(appUsers: appUsers, title: title),
    ),
  );
}
