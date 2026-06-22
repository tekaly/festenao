import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_sdb_user_edit_screen.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

/// Dashboard screen listing a project's users and their access.
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
  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUsersScreenBloc>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      body: StreamBuilder<AdminProjectUsersScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var users = snapshot.data?.users;
          if (users == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (users.isEmpty) {
            return const Center(child: Text('Aucun utilisateur.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var userAccess = users[index];
              var userName = userAccess.name.v?.trimmedNonEmpty();
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(userName ?? userAccess.id),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userName != null)
                      Text(userAccess.id, style: const TextStyle(fontSize: 12)),
                    Text(accessString(intl, userAccess)),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await goToProjectSdbUserEditScreen(
                    context,
                    param: AdminProjectUserEditScreenParam(
                      projectId: bloc.param.id,
                      userId: userAccess.id,
                    ),
                  );
                  bloc.refresh();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un utilisateur',
        onPressed: () async {
          await goToProjectSdbUserEditScreen(
            context,
            param: AdminProjectUserEditScreenParam(
              projectId: bloc.param.id,
              userId: null,
            ),
          );
          bloc.refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Navigate to the project users management screen.
Future<void> goToProjectSdbUsersScreen(
  BuildContext context, {
  required String projectId,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        return BlocProvider<AdminProjectUsersScreenBloc>(
          blocBuilder: () => AdminProjectUsersScreenBloc(
            param: AdminProjectUsersScreenParam(id: projectId),
          ),
          child: const ProjectSdbUsersScreen(),
        );
      },
    ),
  );
}
