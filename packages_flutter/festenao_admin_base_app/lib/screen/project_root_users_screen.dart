import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_admin_app/view/section_tile.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

import '../layout/admin_screen_layout.dart';
import 'project_root_user_edit_screen_bloc.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends AutoDisposeBaseState<AdminUsersScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<AdminUsersScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(
        title: const Text('Users'),
      ),
      body: StreamBuilder<AdminUsersScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var users = snapshot.data?.users;

          if (users == null) {
            return const CenteredProgress();
          } else {
            var users = snapshot.data?.users;
            // devPrint('studies: $list');
            return ListView.builder(
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const BodyContainer(
                    child: SectionTile(titleLabel: 'All admin users'),
                  );
                }
                index--;
                var user = users[index];
                return BodyContainer(
                  child: ListTile(
                    title: Text(user.id),
                    subtitle: Text(user.toMap().toString()),
                    trailing: const TrailingArrow(),
                    onTap: () {
                      goToAdminUserScreen(context,
                          projectId: bloc.param.id, userId: user.id);
                    },
                  ),
                );
              },
              itemCount: users!.length + 1,
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await goToAdminUserEditScreen(context,
              param: AdminUserEditScreenParam(
                  projectId: bloc.param.id, userId: null));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Push to avoid going to root
Future<void> goToAdminUsersScreen(BuildContext context,
    {required String projectId}) async {
  await popAndGoToProjectSubScreen(context,
      projectContext: ByProjectIdAdminAppProjectContext(projectId: projectId),
      contentPath: ProjectUsersContentPath());
}
