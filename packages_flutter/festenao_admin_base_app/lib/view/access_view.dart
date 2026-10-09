/// The access of a project or of the app, on the festenao kit: one role per
/// person (reader, editor, admin, each including the one before), people
/// shown by name and email rather than by id.
library;

import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The role of an access, from its read, write and admin flags.
enum AdminAccessRole {
  /// No access.
  none,

  /// Reads.
  reader,

  /// Reads and writes.
  editor,

  /// Reads, writes and manages the access.
  admin;

  /// The role of [access].
  static AdminAccessRole of(TkCmsCvUserAccessCommon access) {
    if (access.isAdmin) {
      return admin;
    }
    if (access.isWrite) {
      return editor;
    }
    if (access.isRead) {
      return reader;
    }
    return none;
  }

  /// The role of the [admin], [write] and [read] flags of a form.
  static AdminAccessRole ofFlags({
    required bool admin,
    required bool write,
    required bool read,
  }) =>
      admin ? AdminAccessRole.admin : (write ? editor : (read ? reader : none));

  /// The roles a person can be given.
  static const assignable = [reader, editor, admin];

  /// Short label.
  String label(AppLocalizations intl) => switch (this) {
    none => intl.projectAccessNone,
    reader => intl.accessRoleReader,
    editor => intl.accessRoleEditor,
    admin => intl.accessRoleAdmin,
  };

  /// What the role allows.
  String detail(AppLocalizations intl) => switch (this) {
    none => intl.accessRoleNoneDetail,
    reader => intl.accessRoleReaderDetail,
    editor => intl.accessRoleEditorDetail,
    admin => intl.accessRoleAdminDetail,
  };

  /// The status colour of its pill.
  FkStatus get status => switch (this) {
    none => FkStatus.warn,
    reader => FkStatus.muted,
    editor => FkStatus.info,
    admin => FkStatus.accent,
  };

  /// The flags of the role (admin includes write, write includes read).
  ({bool read, bool write, bool admin}) get flags => (
    read: this != none,
    write: this == editor || this == admin,
    admin: this == admin,
  );
}

/// The role pill of [access], and its app role (`role` field) when set.
List<Widget> adminAccessBadges(
  AppLocalizations intl,
  TkCmsCvUserAccessCommon access,
) {
  var role = AdminAccessRole.of(access);
  var appRole = access.role.v?.trimmedNonEmpty();
  return [
    FkStatusPill(role.label(intl), status: role.status),
    if (appRole != null) FkStatusPill(appRole),
  ];
}

/// The name shown for an access: its name, its email or its id.
String adminAccessDisplayName(TkCmsEditedFsUserAccess access) =>
    access.name.v?.trimmedNonEmpty() ??
    access.email.v?.trimmedNonEmpty() ??
    access.id;

/// The line under the name: the email when the name is shown, the id
/// otherwise.
String? adminAccessDisplayDetail(TkCmsEditedFsUserAccess access) {
  var name = access.name.v?.trimmedNonEmpty();
  var email = access.email.v?.trimmedNonEmpty();
  if (name != null) {
    return email ?? access.id;
  }
  if (email != null) {
    return access.id;
  }
  return null;
}

/// A stable category colour index for [id].
int adminAccessCategory(String id) =>
    id.codeUnits.fold<int>(0, (sum, code) => sum + code) % 6;

/// The members of a project or of the app: a search, a row per person with
/// its avatar, name, email and role, an empty state.
class AdminAccessMembersView extends StatefulWidget {
  /// The accesses.
  final List<TkCmsEditedFsUserAccess> users;

  /// The line under the app bar.
  final String? subtitle;

  /// The header actions (add a user).
  final List<Widget> actions;

  /// The signed in user, tagged in the list.
  final String? currentUserId;

  /// Opens an access.
  final void Function(TkCmsEditedFsUserAccess access)? onTap;

  /// Under the list (the path of the collection in debug, a warning).
  final Widget? footer;

  /// The members view.
  const AdminAccessMembersView({
    super.key,
    required this.users,
    this.subtitle,
    this.actions = const [],
    this.currentUserId,
    this.onTap,
    this.footer,
  });

  @override
  State<AdminAccessMembersView> createState() => _AdminAccessMembersViewState();
}

class _AdminAccessMembersViewState extends State<AdminAccessMembersView> {
  var _query = '';

  bool _matches(TkCmsEditedFsUserAccess access) {
    if (_query.isEmpty) {
      return true;
    }
    return [
      access.name.v,
      access.email.v,
      access.id,
    ].any((text) => text?.toLowerCase().contains(_query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var users = widget.users.where(_matches).toList()
      ..sort(
        (a, b) =>
            adminAccessDisplayName(a)
                .toLowerCase()
                .compareTo(adminAccessDisplayName(b).toLowerCase()),
      );
    return FkPage(
      maxWidth: 960,
      children: [
        FkHeader(subtitle: widget.subtitle, actions: widget.actions),
        if (widget.users.length > 3) ...[
          TextField(
            decoration: InputDecoration(
              hintText: intl.accessSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: FestenaoSpace.l),
        ],
        FkSectionTitle(intl.accessMembers(widget.users.length)),
        if (widget.users.isEmpty)
          FkCard(
            child: FkEmpty(
              icon: Icons.group_outlined,
              message: intl.accessNoUser,
            ),
          )
        else if (users.isEmpty)
          FkCard(
            child: FkEmpty(icon: Icons.search_off, message: intl.accessNoMatch),
          )
        else
          FkListCard(
            children: [
              for (var access in users)
                FkRow(
                  leading: FkAvatar(
                    adminAccessDisplayName(access),
                    category: adminAccessCategory(access.id),
                  ),
                  title: adminAccessDisplayName(access),
                  titleTrailing: access.id == widget.currentUserId
                      ? Text(
                          intl.accessYou,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: t.ink3),
                        )
                      : null,
                  subtitle: adminAccessDisplayDetail(access),
                  badges: adminAccessBadges(intl, access),
                  trailing: Icon(Icons.chevron_right, color: t.ink3),
                  onTap: widget.onTap == null
                      ? null
                      : () => widget.onTap!(access),
                ),
            ],
          ),
        if (widget.footer != null) ...[
          const SizedBox(height: FestenaoSpace.xl),
          widget.footer!,
        ],
      ],
    );
  }
}

/// A discreet line with the Firestore path of the access collection, for
/// the developers (debug builds only, see the callers).
class AdminAccessPathNote extends StatelessWidget {
  /// The path.
  final String path;

  /// A path note.
  const AdminAccessPathNote(this.path, {super.key});

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    return Row(
      children: [
        Icon(Icons.storage_outlined, size: 16, color: t.ink3),
        const SizedBox(width: 8),
        Expanded(
          child: SelectableText(
            path,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: t.ink3, fontFamily: t.monoFamily),
          ),
        ),
      ],
    );
  }
}

/// The id of the signed in user, null when unknown (no identity bloc, no
/// Firebase in a test).
String? adminCurrentUserIdOrNull() {
  try {
    return globalTkCmsFbIdentityBloc
        .state
        .valueOrNull
        ?.identity
        ?.userOrAccountId;
  } catch (_) {
    return null;
  }
}
