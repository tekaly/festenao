import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_admin_base_app/layout/admin_screen_layout.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_edit_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/project_root_user_screen_bloc.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_admin_base_app/utils/project_ui_utils.dart';
import 'package:festenao_admin_base_app/view/info_tile.dart';
import 'package:flutter/services.dart';
import 'package:tekartik_app_flutter_widget/app_widget.dart';
import 'package:tekartik_app_flutter_widget/view/body_container.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tkcms_admin_app/audi/tkcms_audi.dart';

class AdminUserScreen extends StatefulWidget {
  const AdminUserScreen({super.key});

  @override
  State<AdminUserScreen> createState() => _AdminUserScreenState();
}

class _AdminUserScreenState extends AutoDisposeBaseState<AdminUserScreen> {
  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var bloc = BlocProvider.of<AdminUserScreenBloc>(context);
    return AdminScreenLayout(
      appBar: AppBar(title: const Text('User')),
      body: StreamBuilder<AdminUserScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var user = snapshot.data?.user;

          if (user == null) {
            return const CenteredProgress();
          } else {
            var userId = user.id;

            // devPrint('studies: $list');
            return ListView(
              children: [
                const SizedBox(height: 16),
                BodyContainer(
                  child: InfoTile(
                    label: 'User ID', // textUserIdLabel,
                    value: userId,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: userId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ID utilisateur copié dans le presse-papier',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                BodyContainer(
                  child: Column(
                    children: [
                      InfoTile(label: 'name', value: user.name.v ?? ''),
                      InfoTile(
                        label: 'Access',
                        value: accessString(intl, user),
                      ),
                      InfoTile(
                        label: 'attributes',
                        value: user.toMap().toString(),
                        onTap: () {
                          // Clipboard.setData(ClipboardData(text: user.name.v!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Nom utilisateur copié dans le presse-papier',
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                /* BodyContainer(
                  child: InfoTile(
                    labelText: textUserEmailLabel,
                    valueText: user.email.v,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.email.v!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Email utilisateur copié dans le presse-papier',
                          ),
                        ),
                      );
                    },
                  ),
                ),
                BodyContainer(
                  child: InfoTile(
                    labelText: textUserIsAdmin,
                    valueText: (user.isAdmin.v ?? false).toString(),
                  ),
                ),
                BodyContainer(
                  child: InfoTile(
                    labelText: textUserIsSimpleUser,
                    valueText: (user.user.v ?? false).toString(),
                  ),
                ),*/
              ],
            );
          }
        },
      ),
      floatingActionButton: StreamBuilder<AdminUserScreenBlocState>(
        stream: bloc.state,
        builder: (context, snapshot) {
          var userId = snapshot.data?.user.id;
          if (userId == null) {
            return Container();
          }
          return FloatingActionButton(
            onPressed: () async {
              var result = await goToAdminProjectUserEditScreen(
                context,
                param: AdminProjectUserEditScreenParam(
                  userId: userId,
                  projectId: bloc.projectId,
                ),
              );
              if (context.mounted) {
                if (result?.deleted ?? false) {
                  Navigator.of(context).pop(); // Go back
                  return;
                }

                if (result?.modified == true) {
                  bloc.refresh();
                }
              }
            },
            child: const Icon(Icons.edit),
          );
        },
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
