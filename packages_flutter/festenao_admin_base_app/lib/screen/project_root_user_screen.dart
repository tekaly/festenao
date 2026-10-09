import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/services.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key});

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends AutoDisposeBaseState<AdminUserScreen> {
  Future<void> _edit(AdminUserScreenBloc bloc, String userId) async {
    var result = await goToAdminProjectUserEditScreen(
      context,
      param: AdminProjectUserEditScreenParam(
        userId: userId,
        projectId: bloc.projectId,
      ),
    );
    if (mounted) {
      if (result?.deleted ?? false) {
        Navigator.of(context).pop(); // Go back
        return;
      }
      if (result?.modified == true) {
        bloc.refresh();
      }
    }
  }

  void _copyId(String userId) {
    var intl = festenaoAdminAppIntl(context);
    Clipboard.setData(ClipboardData(text: userId));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(intl.accessIdCopied)));
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminUserScreenBloc>(context);
    return StreamBuilder<AdminUserScreenBlocState>(
      stream: bloc.state,
      builder: (context, snapshot) {
        var user = snapshot.data?.user;
        return AdminScreenLayout(
          appBar: AppBar(
            title: Text(
              user == null ? intl.userTitle : adminAccessDisplayName(user),
            ),
          ),
          body: user == null
              ? const CenteredProgress()
              : _UserView(
                  user: user,
                  onEdit: () => _edit(bloc, user.id),
                  onCopyId: () => _copyId(user.id),
                ),
        );
      },
    );
  }
}

class _UserView extends StatelessWidget {
  final TkCmsEditedFsUserAccess user;
  final VoidCallback onEdit;
  final VoidCallback onCopyId;

  const _UserView({
    required this.user,
    required this.onEdit,
    required this.onCopyId,
  });

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    var name = adminAccessDisplayName(user);
    var email = user.email.v?.trimmedNonEmpty();
    var role = AdminAccessRole.of(user);
    var appRole = user.role.v?.trimmedNonEmpty();
    var mono = text.bodyMedium?.copyWith(fontFamily: t.monoFamily);
    return FkPage(
      maxWidth: 720,
      children: [
        FkCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FkAvatar(
                    name,
                    category: adminAccessCategory(user.id),
                    size: 56,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: text.titleLarge),
                        if (email != null && email != name)
                          Text(
                            email,
                            style: text.bodyMedium?.copyWith(color: t.ink2),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: adminAccessBadges(intl, user),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(intl.accessEdit),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyId,
                    icon: const Icon(Icons.copy),
                    label: Text(intl.accessCopyId),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: FestenaoSpace.xl),
        FkSectionTitle(intl.accessAccountSection),
        FkListCard(
          children: [
            _KeyValueRow(
              label: intl.accessUserId,
              value: user.id,
              valueStyle: mono,
              trailing: IconButton(
                tooltip: intl.accessCopyId,
                icon: const Icon(Icons.copy, size: 20),
                onPressed: onCopyId,
              ),
            ),
            if (email != null)
              _KeyValueRow(label: intl.emailLabel, value: email),
            _KeyValueRow(
              label: intl.projectAccessRole,
              value: '${role.label(intl)} · ${role.detail(intl)}',
            ),
            if (appRole != null)
              _KeyValueRow(label: intl.accessAppRole, value: appRole),
          ],
        ),
        const SizedBox(height: FestenaoSpace.xl),
        FkCard(
          padding: EdgeInsets.zero,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: Text(intl.accessRawData, style: text.titleSmall),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  user.toMap().toString(),
                  style: mono?.copyWith(fontSize: 12, color: t.ink2),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;

  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    var t = context.festenao;
    var text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelMedium?.copyWith(color: t.ink3)),
                const SizedBox(height: 2),
                SelectableText(value, style: valueStyle ?? text.bodyMedium),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Push to avoid going to root
Future<void> goToAdminUserScreen(
  BuildContext context, {
  required String projectId,
  required String userId,
}) async {
  if (festenaoUseContentPathNavigation) {
    await ContentNavigator.of(context).pushPath<void>(
      ProjectUserContentPath()
        ..project.value = projectId
        ..sub.value = userId,
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () =>
                AdminUserScreenBloc(projectId: projectId, userId: userId),
            child: const AdminUserScreen(),
          );
        },
      ),
    );
  }
}
