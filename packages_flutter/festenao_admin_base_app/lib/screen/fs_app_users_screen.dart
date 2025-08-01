import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/screen/admin_app_scaffold.dart';
import 'package:festenao_admin_base_app/screen/fs_app_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/fs_app_users_screen_bloc.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_admin_base_app/view/app_path.dart';
import 'package:festenao_admin_base_app/view/not_signed_in_tile.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_flutter_widget/view/body_h_padding.dart';
import 'package:tekartik_app_flutter_widget/view/with_header_footer_list_view.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

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
            title: const Text(
              'FsApp Users',
            ), // appIntl(context).ProjectsTitle),
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
              var userAccessList = state.userAccessList;
              return WithHeaderFooterListView.builder(
                header: BodyContainer(
                  child: Column(children: [AppPathTile(appPath: bloc.appPath)]),
                ),
                footer: state.identity == null
                    ? const BodyContainer(
                        child: BodyHPadding(
                          child: Center(
                            child: Column(
                              children: [
                                IdentityWarningTile(), // appIntl(context).notSignedInInfo),
                                SizedBox(height: 8),
                                /*
                            ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push<void>(
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              globalAuthFlutterUiService
                                                  .loginScreen(
                                                      firebaseAuth:
                                                          globalFirebaseContext
                                                              .auth)));
                                },
                                child:
                                    Text(appIntl(context).signInButtonLabel)),*/
                              ],
                            ),
                          ),
                        ),
                      )
                    : null,
                itemCount: userAccessList.length,
                itemBuilder: (context, index) {
                  var userAccess = userAccessList[index];
                  var userId = userAccess.id;
                  return BodyContainer(
                    child: ListTile(
                      title: Text(userAccess.id),
                      subtitle: Text(accessString(intl, userAccess)),
                      onTap: () async {
                        if (bloc.selectMode) {
                          Navigator.of(
                            context,
                          ).pop(FsAppUserSelectResult(userId: userId));
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
                        //  await goToNotesScreen(context, Project.ref);
                      },
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: (state?.identity != null)
              ? FloatingActionButton(
                  onPressed: () async {
                    // ignore: unused_local_variable
                    var result = await goToAppUserEditScreen(
                      context,
                      param: FsAppUserEditScreenParam(
                        userId: null,
                        appId: bloc.appId,
                        projectId: bloc.projectId,
                      ),
                    );

                    bloc.refresh();
                  },
                  child: const Icon(Icons.add),
                )
              : null,
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
