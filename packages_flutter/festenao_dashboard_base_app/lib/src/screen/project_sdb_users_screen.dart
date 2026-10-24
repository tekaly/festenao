import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_dashboard_base_app/src/provider/project_access_providers.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_user_edit_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// The users of a project and their role, on the festenao kit
/// ([AdminAccessMembersView], the one of the admin app).
///
/// Reuses [AdminProjectUsersScreenBloc] for the firestore stream and the
/// dashboard user edit screen for create/edit/delete.
class ProjectSdbUsersScreen extends StatefulWidget {
  const ProjectSdbUsersScreen({super.key});

  @override
  State<ProjectSdbUsersScreen> createState() => _ProjectSdbUsersScreenState();
}

class _ProjectSdbUsersScreenState
    extends AutoDisposeBaseState<ProjectSdbUsersScreen> {
  Future<void> _edit(AdminProjectUsersScreenBloc bloc, String? userId) async {
    await goToProjectSdbUserEditScreen(
      context,
      param: AdminProjectUserEditScreenParam(
        projectId: bloc.param.id,
        userId: userId,
      ),
      entityAccess: bloc.entityAccess,
    );
    bloc.refresh();
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUsersScreenBloc>(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(intl.projectUsersTitle),
        actions: [
          IconButton(
            tooltip: MaterialLocalizations.of(context)
                .refreshIndicatorSemanticLabel,
            icon: const Icon(Icons.refresh),
            onPressed: bloc.refresh,
          ),
        ],
      ),
      body: StreamBuilder<AdminProjectUsersScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var users = snapshot.data?.users;
          if (users == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return AdminAccessMembersView(
            users: users,
            subtitle: intl.accessSubtitle,
            currentUserId: dashboardCurrentUserIdOrNull(context),
            actions: [
              FilledButton.icon(
                onPressed: () => _edit(bloc, null),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(intl.accessAddUser),
              ),
            ],
            onTap: (access) => _edit(bloc, access.id),
            footer: kDebugMode ? AdminAccessPathNote(bloc.usersPath) : null,
          );
        },
      ),
    );
  }
}

/// The id of the signed in user: the dashboard identity when [context] is
/// below a provider scope, the global identity bloc otherwise, null when
/// unknown.
String? dashboardCurrentUserIdOrNull(BuildContext context) {
  try {
    var identity = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(rpdIdentityProvider);
    if (identity != null) {
      return identity.userOrAccountId;
    }
  } catch (_) {
    // No provider scope.
  }
  return adminCurrentUserIdOrNull();
}

/// Navigate to the project users management screen.
///
/// [entityAccess] manages the access of another [TkCmsFsEntity] than the
/// festenao project (a songbook...).
Future<void> goToProjectSdbUsersScreen(
  BuildContext context, {
  required String projectId,
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsEntity>? entityAccess,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        return BlocProvider<AdminProjectUsersScreenBloc>(
          blocBuilder: () => AdminProjectUsersScreenBloc(
            param: AdminProjectUsersScreenParam(id: projectId),
            entityAccess: entityAccess,
          ),
          child: const ProjectSdbUsersScreen(),
        );
      },
    ),
  );
}
