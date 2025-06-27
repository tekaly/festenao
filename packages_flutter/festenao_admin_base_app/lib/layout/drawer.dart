import 'package:festenao_admin_base_app/admin_app/admin_app_project_context.dart';
import 'package:festenao_admin_base_app/route/route_paths.dart';
import 'package:festenao_admin_base_app/screen/admin_artists_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_events_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_exports_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_images_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_infos_screen.dart';
import 'package:festenao_admin_base_app/screen/admin_metas_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_screen.dart';
import 'package:festenao_admin_base_app/screen/project_root_users_screen.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:festenao_admin_base_app/sembast/projects_db_bloc.dart';
import 'package:flutter/material.dart';
import 'package:sembast_db_explorer/sembast_db_explorer.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

/// Admin go to app parent action
VoidCallback? adminGoToAppParentAction;
// Compat
VoidCallback? get adminParentAction => adminGoToAppParentAction;

set adminParentAction(VoidCallback? value) => adminGoToAppParentAction = value;

class ListDrawer extends StatefulWidget {
  final bool isPopupDrawer;
  final bool? content;

  const ListDrawer({super.key, this.isPopupDrawer = false, this.content});

  @override
  State<ListDrawer> createState() => _ListDrawerState();
}

class _ListDrawerState extends State<ListDrawer> {
  int selectedItem = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.content ?? false) {
      return Hero(tag: UniqueKey(), child: buildListView(context));
    }
    return Drawer(child: SafeArea(child: buildListView(context)));
  }

  Widget buildListView(BuildContext context) {
    var sb = globalProjectsDbBloc;
    FestenaoAdminAppProjectContext? appProjectContextOrNull;
    if (sb is MultiProjectsDbBloc) {
      final routeName = ModalRoute.of(context)?.settings.name;
      var contentPath = AdminAppRootProjectContextPath()
        ..fromPath(ContentPath.fromString(routeName ?? ''));
      var projectId = contentPath.projectIdOrNull;
      if (projectId != null) {
        appProjectContextOrNull = ByProjectIdAdminAppProjectContext(
          projectId: projectId,
        );
      }
    } else if (sb is SingleProjectDbBloc) {
      appProjectContextOrNull = ByProjectIdAdminAppProjectContext(
        projectId: 'compat',
      );
    } else {
      throw UnsupportedError(sb.toString());
    }
    var appProjectContext = appProjectContextOrNull;

    return ListView(
      shrinkWrap: widget.content ?? false,
      children: [
        InkWell(
          onTap: () {
            // goToHomeScreen(context);
          },
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 5,
            child: Container(
              color: Theme.of(context).colorScheme.secondary,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                  //child: Image(image: assetGaelLogo718.image),
                ),
              ),
            ),
          ),
        ),
        /*
        if (adminGoToAppParentAction != null)
          ListTile(
              title: const Text('Go to app'),
              onTap: () {
                adminGoToAppParentAction!();
              }),*/
        ListTile(
          title: const Text('Festenao'),
          onTap: () async {
            ContentNavigator.popToRoot(context);
          },
        ),
        if (appProjectContext != null) ...[
          ListTile(
            title: const Text('Project'),
            onTap: () async {
              await goToProjectRootScreen(
                context,
                projectId: appProjectContext.projectId,
              );
            },
          ),
          ListTile(
            title: const Text('Metas'),
            onTap: () {
              goToAdminMetasScreen(context, projectContext: appProjectContext);
            },
          ),
          ListTile(
            title: const Text('Artists'),
            onTap: () async {
              await goToAdminArtistsScreen(
                context,
                projectContext: appProjectContext,
              );
            },
          ),
          ListTile(
            title: const Text('Events'),
            onTap: () {
              goToAdminEventsScreen(context, projectContext: appProjectContext);
            },
          ),
          ListTile(
            title: const Text('Images'),
            onTap: () {
              goToAdminImagesScreen(context, projectContext: appProjectContext);
            },
          ),
          ListTile(
            title: const Text('Infos'),
            onTap: () async {
              await goToAdminInfosScreen(
                context,
                projectContext: appProjectContext,
              );
            },
          ),
          ListTile(
            title: const Text('Publish'),
            onTap: () async {
              await goToAdminExportsScreen(
                context,
                projectContext: appProjectContext,
              );
            },
          ),
          ListTile(
            title: const Text('Users'),
            onTap: () async {
              await goToAdminUsersScreen(
                context,
                projectId: appProjectContext.projectId,
              );
            },
          ),
          /*
        if (app.goToLoginScreen != null)
          ListTile(
            title: const Text('Auth'),
            onTap: () async {
              await app.goToLoginScreen!(
                  context, LoginScreenOptions(stayWhenLoggedIn: true));
            },
          ),
        ListTile(
          title: const Text('Users'),
          onTap: () async {
            await goToAdminUsersScreen(context);
          },
        ),
        ListTile(
          title: const Text('Publish'),
          onTap: () async {
            await goToAdminExportsScreen(context);
          },
        ),

        ListTile(
          title: const Text('Sembast db exploreer'),
          onTap: () async {
            var db = await festenaoDb.database;
            if (context.mounted) {
              await showDatabaseExplorer(context, db);
            }
          },
        )
        /*
        DrawerItem(
          leading: Icon(Icons.logout),
          label: textSignOutLabel,
          onTap: () {
            goToStartScreen(context,
                param: StartScreenParam(forceLogout: true));
          },
        ),*/
        /*
        DrawerItem(
          leading: Icon(Icons.stream),
          label: textStudiesTitle,
          onTap: () {
            goToStartScreen(context,
                param: StartScreenParam(forceLogout: true));
          },
        ),*/

         */
        ],
        ListTile(
          title: const Text('Projects DB Sembast db explorer'),
          onTap: () async {
            var db = globalProjectsDb.db;
            if (context.mounted) {
              await showDatabaseExplorer(context, db);
            }
          },
        ),
      ],
    );
  }

  /*
  @override
  Widget build(BuildContext context) {
    return Drawer(
        child: SafeArea(
      child: ListView(
        children: [
          InkWell(
            onTap: () {
              // goToHomeScreen(context);
            },
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 5,
              child: Container(
                color: Theme.of(context).colorScheme.secondary,
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                    //child: Image(image: assetGaelLogo718.image),
                  ),
                ),
              ),
            ),
          ),
          if (adminGoToAppParentAction != null)
            ListTile(
                title: const Text('Go to app'),
                onTap: () {
                  adminGoToAppParentAction!();
                }),
          /*tmp
          ListTile(
              title: const Text('Meta'),
              onTap: () {
                goToAdminMetasScreen(context);
              }),
          ListTile(
              title: const Text('Artists'),
              onTap: () {
                goToAdminArtistsScreen(context);
              }),
          ListTile(
              title: const Text('Events'),
              onTap: () {
                goToAdminEventsScreen(context);
              }),
          ListTile(
              title: const Text('Images'),
              onTap: () {
                goToAdminImagesScreen(context);
              }),
          ListTile(
              title: const Text('Infos'),
              onTap: () {
                goToAdminInfosScreen(context);
              }),*/
          const Divider(),

          /*tmp
          if (app.goToLoginScreen != null)
            ListTile(
              title: const Text('Auth'),
              onTap: () async {
                await app.goToLoginScreen!(
                    context, LoginScreenOptions(stayWhenLoggedIn: true));
              },
            ),
          ListTile(
            title: const Text('Users'),
            onTap: () async {
              await goToAdminUsersScreen(context);
            },
          ),
          ListTile(
            title: const Text('Publish'),
            onTap: () async {
              await goToAdminExportsScreen(context);
            },
          ),*/

          /*
          DrawerItem(
            leading: Icon(Icons.logout),
            label: textSignOutLabel,
            onTap: () {
              goToStartScreen(context,
                  param: StartScreenParam(forceLogout: true));
            },
          ),*/
          /*
          DrawerItem(
            leading: Icon(Icons.stream),
            label: textStudiesTitle,
            onTap: () {
              goToStartScreen(context,
                  param: StartScreenParam(forceLogout: true));
            },
          ),*/
        ],
      ),
    ));
    /*
    return Drawer(
      child: SafeArea(
        child: ValueStreamBuilder<TopLevelPage>(
            stream: appNavigationBloc.currentTopLevelPage,
            builder: (context, snapshot) {
              return ValueStreamBuilder<AppCurrentUserState>(
                  stream: appCurrentUserBloc.currentUser,
                  builder: (context, currentUserSnapshot) {
                    var user = currentUserSnapshot.data?.user;
                    return ListView(
                      children: [
                        if (user?.photoURL != null) ...[
                          SizedBox(
                            height: 16,
                          ),
                          Center(
                            child: ClipOval(
                                child: Image.network(user.photoURL,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover)),
                          )
                        ],
                        if (user.displayName != null)
                          ListTile(
                            title: Center(
                              child: Text(
                                user.displayName,
                                style: textTheme.headline6,
                              ),
                            ),
                            subtitle: Center(
                              child: user.email == null
                                  ? null
                                  : Text(
                                      user.email,
                                      style: textTheme.bodyText2,
                                    ),
                            ),
                          )
                        else
                          SizedBox(height: 16),
                        ListTile(
                            selected: snapshot.data == TopLevelPage.home,
                            leading: Icon(Icons.home),
                            title: Text(textHomeTitle),
                            onTap: () {
                              if (widget.isPopupDrawer ?? false) {
                                Navigator.of(context).pop();
                              }
                              goToHomePage(context);
                            }),
                        if (isUserAuthorized(
                            currentUserSnapshot.data.globalUser)) ...[
                          ListTile(
                              selected: snapshot.data == TopLevelPage.slideshow,
                              leading: Icon(Icons.slideshow),
                              title: Text(textSlideshowsTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToSlideshowsPage(context);
                              }),
                          ListTile(
                              selected: snapshot.data == TopLevelPage.slides,
                              leading: SlideLeading(),
                              title: Text(textSlidesTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToSlideAssetsPage(context);
                              }),
                          ListTile(
                              selected:
                                  snapshot.data == TopLevelPage.watchModel,
                              leading: WatchModelLeading(),
                              title: Text(textWatchModelsTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToWatchModelsPage(context);
                              }),
                          ListTile(
                              selected: snapshot.data == TopLevelPage.app,
                              leading: AppLeading(),
                              title: Text(textAppsTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToAppsPage(context);
                              }),
                          ListTile(
                              selected: snapshot.data == TopLevelPage.category,
                              leading: CategoryLeading(),
                              title: Text(textCategoriesTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToCategoriesPage(context);
                              }),
                          ListTile(
                              selected:
                                  snapshot.data == TopLevelPage.validateData,
                              leading: ValidateDataLeading(),
                              title: Text(textValidateDataTitle),
                              onTap: () {
                                if (widget.isPopupDrawer ?? false) {
                                  Navigator.of(context).pop();
                                }
                                goToValidateDataPage(context);
                              }),
                        ],
                        ListTile(
                            selected: snapshot.data == TopLevelPage.account,
                            leading: Icon(Icons.person),
                            title: Text(textAccountTitle),
                            onTap: () {
                              if (widget.isPopupDrawer ?? false) {
                                Navigator.of(context).pop();
                              }
                              goToAccountProfilePage(context);
                            }),
                        ListTile(
                            selected:
                                snapshot.data == TopLevelPage.notification,
                            leading: Icon(Icons.notification_important),
                            title: Text(textNotificationTitle),
                            onTap: () {
                              if (widget.isPopupDrawer ?? false) {
                                Navigator.of(context).pop();
                              }
                              goToNotificationPage(context);
                            }),
                        ListTile(
                            selected: snapshot.data == TopLevelPage.infos,
                            leading: Icon(Icons.cloud_circle_rounded),
                            title: Text(textInformationTitle),
                            subtitle: Text(textInformationSubtitle),
                            onTap: () {
                              if (widget.isPopupDrawer ?? false) {
                                Navigator.of(context).pop();
                              }
                              goToInfosPage(context);
                            })
                        /*
                ...Iterable<int>.generate(numItems).toList().map((i) {
                  return ListTile(
                    enabled: true,
                    selected: i == selectedItem,
                    leading: const Icon(Icons.favorite),
                    title: Text(
                      'text ${i + 1}',
                    ),
                    onTap: () {
                      setState(() {
                        selectedItem = i;
                      });
                    },
                  );
                }),
                 */
                      ],
                    );
                  });
            }),
      ),
    );

     */
  }*/
}
