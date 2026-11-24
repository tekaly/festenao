import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tkcms_common/tkcms_api.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The admins of an app: its app entity access
/// (`access/app/entity_id/<appId>/user_access`), listed from firestore (the
/// rules let an admin of the app read it) and changed through the api of the
/// app (`entity/app/set-user-access`, `create-email-invite`...): an email is
/// made an admin right away when it has an account, invited otherwise; a
/// super admin also makes super admins (the server checks it).
class DashboardAppAdminsScreen extends StatefulWidget {
  /// The api of the app (its server serves the app entity commands).
  final TkCmsApiServiceBaseV2 apiService;

  /// The app entities (`app/<appId>`).
  final TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>
  appEntityAccess;

  /// The app.
  final String appId;

  /// The firestore the admins are read from.
  final Firestore firestore;

  /// The signed in user, an admin of the app.
  final String userId;

  /// The admins of [appId].
  const DashboardAppAdminsScreen({
    super.key,
    required this.apiService,
    required this.appEntityAccess,
    required this.appId,
    required this.firestore,
    required this.userId,
  });

  @override
  State<DashboardAppAdminsScreen> createState() =>
      _DashboardAppAdminsScreenState();
}

/// The access an admin is given: admin, or super admin.
enum _AdminGrant { admin, superAdmin }

/// The menu of an admin: a grant, or its removal (a popup menu never selects
/// a null value: it means cancelled).
enum _AdminMenu {
  admin(_AdminGrant.admin),
  superAdmin(_AdminGrant.superAdmin),
  remove(null);

  const _AdminMenu(this.grant);

  /// The grant, null to remove the access.
  final _AdminGrant? grant;
}

class _DashboardAppAdminsScreenState extends State<DashboardAppAdminsScreen> {
  late final _client = FestenaoApiFsEntityClient<TkCmsFsEntity>(
    apiService: widget.apiService,
    entityAccess: widget.appEntityAccess,
  );
  List<TkCmsEditedFsUserAccess>? _admins;
  List<TkCmsCvEmailInvite>? _invites;
  Object? _error;
  var _busy = false;

  bool get _isSuperAdmin =>
      _admins?.any(
        (access) => access.id == widget.userId && access.hasSuperAdminRole,
      ) ??
      false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      var list = await widget.appEntityAccess
          .fsEntityUserAccessCollectionRef(widget.appId)
          .cast<TkCmsEditedFsUserAccess>()
          .get(widget.firestore);
      String label(TkCmsEditedFsUserAccess access) =>
          (access.name.v ?? access.email.v ?? access.id).toLowerCase();
      // A copy: the list read may be read only. The super admins first.
      var admins = [...list.where((access) => access.isAdmin)]
        ..sort((a, b) {
          if (a.hasSuperAdminRole != b.hasSuperAdminRole) {
            return a.hasSuperAdminRole ? -1 : 1;
          }
          return label(a).compareTo(label(b));
        });
      var invites = await _client.listEntityEmailInvites(
        entityId: widget.appId,
        status: tkCmsEmailInviteStatusPending,
      );
      if (mounted) {
        setState(() {
          _admins = admins;
          _invites = invites;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    }
  }

  String _errorText(Object error) =>
      error is ApiException ? (error.message ?? '$error') : '$error';

  /// Runs [action] (busy) then reloads, its message or its error snacked.
  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busy = true);
    try {
      var message = await action();
      if (message != null && mounted) {
        await muiSnack(context, message);
      }
    } catch (e) {
      if (mounted) {
        await muiSnack(context, _errorText(e));
      }
    } finally {
      await _load();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _confirm(String content, String action) async {
    var intl = festenaoAdminAppIntl(context);
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(intl.cancelButtonLabel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// The access of [grant], the other roles of [current] kept.
  TkCmsCvUserAccess _access(
    _AdminGrant? grant, {
    TkCmsCvUserAccessCommon? current,
  }) {
    var access = TkCmsCvUserAccess();
    var otherRoles = [
      for (var role in current?.roles ?? const <String>[])
        if (role.isNotEmpty && role != roleSuperAdmin && role != roleAdmin)
          role,
    ];
    switch (grant) {
      case null:
        break;
      case _AdminGrant.admin:
        access.grantAdminAccess();
      case _AdminGrant.superAdmin:
        access.grantSuperAdminAccess();
    }
    var roles = [...access.roles, ...otherRoles];
    if (grant != null && roles.isNotEmpty) {
      access.role.v = roles.join(',');
    }
    return access..fixAccess();
  }

  Future<void> _add() async {
    var intl = festenaoAdminAppIntl(context);
    var asked = await showDialog<(String, _AdminGrant)>(
      context: context,
      builder: (_) => _AddAdminDialog(superAdmin: _isSuperAdmin),
    );
    if (asked == null || !mounted) {
      return;
    }
    var (email, grant) = asked;
    var noAccount = false;
    await _run(() async {
      try {
        await _client.setEntityUserAccess(
          entityId: widget.appId,
          email: email,
          userAccess: _access(grant),
        );
        return intl.appAdminsAdded(email);
      } catch (e) {
        if (festenaoApiIsNotFoundError(e)) {
          noAccount = true;
          return null;
        }
        rethrow;
      }
    });
    if (!noAccount ||
        !mounted ||
        !await _confirm(
          intl.projectEmailNoAccount(email),
          intl.projectEmailInviteSend,
        )) {
      return;
    }
    await _run(() async {
      var result = await _client.sendEntityEmailInvite(
        entityId: widget.appId,
        email: email,
        fsUserAccess: TkCmsFsUserAccess()..copyAccessFrom(_access(grant)),
      );
      return result.mailSent.v == true
          ? intl.projectEmailInviteSent(email)
          : intl.projectEmailInviteSaved(email);
    });
  }

  Widget _adminTile(TkCmsEditedFsUserAccess access) {
    var intl = festenaoAdminAppIntl(context);
    var isMe = access.id == widget.userId;
    var superAdmin = access.hasSuperAdminRole;
    var locked = isMe || (superAdmin && !_isSuperAdmin);
    var label = access.name.v ?? access.email.v ?? access.id;
    return ListTile(
      leading: Icon(
        superAdmin
            ? Icons.verified_user_outlined
            : Icons.admin_panel_settings_outlined,
      ),
      title: Text(isMe ? '$label (${intl.appAdminsYou})' : label),
      subtitle: Text(
        [
          if (access.email.v case var email? when email != label) email,
          if (superAdmin) intl.appAdminsSuperAdmin else intl.appAdminsAdmin,
        ].join(' · '),
      ),
      trailing: locked || _busy
          ? null
          : PopupMenuButton<_AdminMenu>(
              onSelected: (menu) async {
                var grant = menu.grant;
                if (grant == null &&
                    !await _confirm(
                      intl.appAdminsRemoveConfirm(label),
                      intl.appAdminsRemove,
                    )) {
                  return;
                }
                await _run(() async {
                  await _client.setEntityUserAccess(
                    entityId: widget.appId,
                    userId: access.id,
                    userAccess: _access(grant, current: access),
                  );
                  return null;
                });
              },
              itemBuilder: (_) => [
                if (_isSuperAdmin && !superAdmin)
                  PopupMenuItem(
                    value: _AdminMenu.superAdmin,
                    child: Text(intl.appAdminsSuperAdmin),
                  ),
                if (superAdmin)
                  PopupMenuItem(
                    value: _AdminMenu.admin,
                    child: Text(intl.appAdminsAdmin),
                  ),
                PopupMenuItem(
                  value: _AdminMenu.remove,
                  child: Text(intl.appAdminsRemove),
                ),
              ],
            ),
    );
  }

  Widget _inviteTile(TkCmsCvEmailInvite invite) {
    var intl = festenaoAdminAppIntl(context);
    var email = invite.email.v ?? '';
    return ListTile(
      leading: const Icon(Icons.mail_outline),
      title: Text(email),
      subtitle: Text(
        invite.hasSuperAdminRole
            ? intl.appAdminsSuperAdmin
            : intl.appAdminsAdmin,
      ),
      trailing: IconButton(
        tooltip: intl.projectEmailInviteRevoke,
        icon: const Icon(Icons.delete_outline),
        onPressed: _busy
            ? null
            : () async {
                if (await _confirm(
                  intl.projectEmailInviteRevokeConfirm(email),
                  intl.projectEmailInviteRevoke,
                )) {
                  await _run(() async {
                    await _client.deleteEntityEmailInvite(
                      entityId: widget.appId,
                      inviteId: invite.inviteId.v!,
                    );
                    return null;
                  });
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var admins = _admins;
    var invites = _invites;
    var error = _error;
    return Scaffold(
      appBar: AppBar(
        title: Text(intl.appAdminsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _busy ? null : _load,
          ),
        ],
      ),
      floatingActionButton: admins == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _add,
              icon: const Icon(Icons.person_add_alt),
              label: Text(intl.appAdminsAdd),
            ),
      body: error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_errorText(error)),
              ),
            )
          : admins == null || invites == null
          ? const Center(child: CircularProgressIndicator())
          : FkPage(
              maxWidth: FestenaoSpace.readingWidth,
              children: [
                if (_busy) const LinearProgressIndicator(),
                FkCard(child: Text(intl.appAdminsInformation)),
                const SizedBox(height: FestenaoSpace.xl),
                FkSectionTitle(intl.appAdminsTitle),
                FkCard(
                  child: Column(
                    children: [for (var admin in admins) _adminTile(admin)],
                  ),
                ),
                const SizedBox(height: FestenaoSpace.xl),
                FkSectionTitle(intl.appAdminsPending),
                FkCard(
                  child: invites.isEmpty
                      ? FkEmpty(
                          icon: Icons.mail_outline,
                          message: intl.appAdminsNone,
                        )
                      : Column(
                          children: [
                            for (var invite in invites) _inviteTile(invite),
                          ],
                        ),
                ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}

class _AddAdminDialog extends StatefulWidget {
  /// The caller is a super admin: super admin offered.
  final bool superAdmin;

  const _AddAdminDialog({required this.superAdmin});

  @override
  State<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends State<_AddAdminDialog> {
  final _email = TextEditingController();
  var _grant = _AdminGrant.admin;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _ok() {
    var email = tkCmsNormalizeInviteEmail(_email.text);
    if (email == null || !email.contains('@')) {
      return;
    }
    Navigator.of(context).pop((email, _grant));
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    return AlertDialog(
      title: Text(intl.appAdminsAdd),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: intl.projectEmailInviteEmailLabel,
            ),
            onSubmitted: (_) => _ok(),
          ),
          if (widget.superAdmin) ...[
            const SizedBox(height: 16),
            SegmentedButton<_AdminGrant>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _AdminGrant.admin,
                  label: Text(intl.appAdminsAdmin),
                ),
                ButtonSegment(
                  value: _AdminGrant.superAdmin,
                  label: Text(intl.appAdminsSuperAdmin),
                ),
              ],
              selected: {_grant},
              onSelectionChanged: (selection) =>
                  setState(() => _grant = selection.first),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(intl.cancelButtonLabel),
        ),
        TextButton(onPressed: _ok, child: Text(intl.projectEmailAddNow)),
      ],
    );
  }
}

/// Opens the admins of [appId] (see [DashboardAppAdminsScreen]).
Future<void> goToDashboardAppAdminsScreen(
  BuildContext context, {
  required TkCmsApiServiceBaseV2 apiService,
  required TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>
  appEntityAccess,
  required String appId,
  required Firestore firestore,
  required String userId,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => DashboardAppAdminsScreen(
      apiService: apiService,
      appEntityAccess: appEntityAccess,
      appId: appId,
      firestore: firestore,
      userId: userId,
    ),
  ),
);
