import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/fs_app_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/view/access_view.dart';
import 'package:festenao_admin_base_app/view/identity_info_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_auth.dart';

import 'fs_app_user_edit_screen_bloc.dart';

/// Projects screen
class FsAppUsersScreen extends StatefulWidget {
  /// Projects screen
  const FsAppUsersScreen({super.key});

  @override
  State<FsAppUsersScreen> createState() => _FsAppUsersScreenState();
}

class FsAppUserSelectResult {
  final String userId;

  FsAppUserSelectResult({required this.userId});

  @override
  String toString() => 'FsAppUserSelectResult(projectRef: $userId)';
}

class _FsAppUsersScreenState extends State<FsAppUsersScreen> {
  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<FsAppUsersScreenBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var state = snapshot.data;

        return FestenaoAdminAppScaffold(
          appBar: AppBar(
            title: Text(intl.accessTitle),
            /*actions: [
                IconButton(
                    onPressed: () {
                      ContentNavigator.of(context)
                          .pushPath<void>(SettingsContentPath());
                    },
                    icon: const Icon(Icons.settings)),
              ],*/
            // automaticallyImplyLeading: false,
          ),
          body: Builder(
            builder: (context) {
              if (state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              Future<void> add() async {
                await goToAppUserEditScreen(
                  context,
                  param: FsAppUserEditScreenParam(
                    userId: null,
                    appId: bloc.appId,
                    projectId: bloc.projectId,
                  ),
                );
                bloc.refresh();
              }

              return AdminAccessMembersView(
                users: state.userAccessList,
                subtitle: intl.accessAppSubtitle,
                currentUserId: state.identity?.userOrAccountId,
                actions: [
                  if (state.identity != null && !bloc.selectMode)
                    FilledButton.icon(
                      onPressed: add,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(intl.accessAddUser),
                    ),
                ],
                onTap: (userAccess) async {
                  var userId = userAccess.id;
                  if (bloc.selectMode) {
                    Navigator.of(context)
                        .pop(FsAppUserSelectResult(userId: userId));
                  } else {
                    var result = await goToAppUserEditScreen(
                      context,
                      param: FsAppUserEditScreenParam(
                        userId: userId,
                        appId: bloc.appId,
                        projectId: bloc.projectId,
                      ),
                    );
                    if (result?.modified ?? false) {
                      bloc.refresh();
                    }
                  }
                },
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.identity == null) const IdentityWarningTile(),
                    if (kDebugMode) AdminAccessPathNote(bloc.appPath),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Go to User screen
Future<Object?> goToFsAppUsersScreen(
  BuildContext context, {
  String? appId,
  String? projectId,
}) async {
  return Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        blocBuilder: () =>
            FsAppUsersScreenBloc(appId: appId, projectId: projectId),
        child: const FsAppUsersScreen(),
      ),
    ),
  );
}

/// Go to Users screen
Future<FsAppUserSelectResult?> selectFsAppUser(
  BuildContext context, {
  String? appId,
  String? projectId,
}) async {
  var result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        blocBuilder: () => FsAppUsersScreenBloc(
          selectMode: true,
          appId: appId,
          projectId: projectId,
        ),
        child: const FsAppUsersScreen(),
      ),
    ),
  );
  if (result is FsAppUserSelectResult) {
    return result;
  }
  return null;
}
