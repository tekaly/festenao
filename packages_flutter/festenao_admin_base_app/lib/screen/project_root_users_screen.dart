import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:flutter/foundation.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

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
  Future<void> _add(AdminProjectUsersScreenBloc bloc) async {
    await goToAdminProjectUserEditScreen(
      context,
      param: AdminProjectUserEditScreenParam(
        projectId: bloc.param.id,
        userId: null,
      ),
    );
    bloc.refresh();
  }

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminProjectUsersScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(
        title: Text(intl.accessTitle),
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
            return const CenteredProgress();
          }
          return AdminAccessMembersView(
            users: users,
            subtitle: intl.accessSubtitle,
            currentUserId: adminCurrentUserIdOrNull(),
            actions: [
              FilledButton.icon(
                onPressed: () => _add(bloc),
                icon: const Icon(Icons.person_add_alt_1),
                label: Text(intl.accessAddUser),
              ),
            ],
            onTap: (access) async {
              await goToAdminUserScreen(
                context,
                projectId: bloc.param.id,
                userId: access.id,
              );
              bloc.refresh();
            },
            footer: kDebugMode ? AdminAccessPathNote(bloc.usersPath) : null,
          );
        },
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
