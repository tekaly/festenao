import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_admin_app/view/body_container.dart';
import 'package:tkcms_admin_app/view/section_tile.dart';
import 'package:tkcms_admin_app/view/trailing_arrow.dart';

import '../layout/admin_screen_layout.dart';
import 'project_root_user_edit_screen_bloc.dart';

class AdminProjectUsersScreen extends StatefulWidget {
  const AdminProjectUsersScreen({super.key});

  @override
  State<AdminProjectUsersScreen> createState() =>
      _AdminProjectUsersScreenState();
}

class _AdminProjectUsersScreenState
    extends AutoDisposeBaseState<AdminProjectUsersScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUsersScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('Users')),
      body: StreamBuilder<AdminProjectUsersScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var users = snapshot.data?.users;

          if (users == null) {
            return const CenteredProgress();
          } else {
            var users = snapshot.data!.users;
            // devPrint('studies: $list');
            return WithHeaderFooterListView.builder(
              header: BodyContainer(
                child: Column(
                  children: [
                    SectionTile(
                      titleLabel: 'All admin users',
                      onTap: () {
                        bloc.refresh();
                      },
                    ),
                    ListTile(
                      title: Text(bloc.usersPath),
                      leading: const Icon(Icons.info_outlined),
                      onTap: () {
                        bloc.refresh();
                      },
                      dense: true,
                    ),
                  ],
                ),
              ),

              itemBuilder: (context, index) {
                var userAccess = users[index];
                var userId = userAccess.id;
                var userName = userAccess.name.v?.trimmedNonEmpty();
                return BodyContainer(
                  child: ListTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (userName != null)
                          Text(userName, style: const TextStyle(fontSize: 12)),
                        Text(userAccess.id),
                      ],
                    ),
                    subtitle: Text(accessString(intl, userAccess)),
                    trailing: const TrailingArrow(),
                    onTap: () async {
                      await goToAdminUserScreen(
                        context,
                        projectId: bloc.param.id,
                        userId: userId,
                      );
                      bloc.refresh();
                    },
                  ),
                );
              },
              itemCount: users.length,
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await goToAdminProjectUserEditScreen(
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

/// Push to avoid going to root
Future<void> goToAdminProjectUsersScreen(
  BuildContext context, {
  required FestenaoAdminAppProjectContext projectContext,
  TransitionDelegate? transitionDelegate,
}) async {
  await popAndGoToProjectSubScreen(
    context,
    projectContext: projectContext,
    contentPath: ProjectUsersContentPath(),
    transitionDelegate: transitionDelegate,
  );
}
