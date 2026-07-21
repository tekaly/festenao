import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_screen.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class DashboardHomePage extends ConsumerWidget {
  static String get routeName => 'home';

  static String get routeLocation => '/';

  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var authStateValue = ref.watch(rpdTkCmsFbIdentityBlocStateProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(title: Text('Festenao Dashboard'), floating: true),
          SliverFillRemaining(
            hasScrollBody: false,
            child: authStateValue.maybeWhen(
              orElse: () => const SizedBox.shrink(),
              data: ((authState) {
                var identity = authState.identity;
                return Column(
                  children: [
                    if (identity != null) ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Welcome to Festenao Dashboard'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.list),
                        title: const Text('Projects'),
                        onTap: () {
                          context.pushNamed(
                            DashboardProjectsAccessScreen.routeName,
                          );
                        },
                      ),
                    ],
                    if (kDebugMode)
                      ListTile(
                        leading: const Icon(Icons.bug_report),
                        title: const Text('Debug'),
                        onTap: () {
                          context.pushNamed('debug');
                        },
                      ),
                    if (identity != null) ...[
                      ...?ref
                          .watch(rpdUserProjectsProvider(identity.userId!))
                          .value
                          ?.map((userProject) {
                            return ListTile(
                              title: Text(
                                userProject.name.v ??
                                    userProject.uid.v ??
                                    'Unnamed project',
                              ),
                              onTap: () {
                                var projectId = userProject.uid.v;
                                if (projectId != null) {
                                  context.push(
                                    DashboardProjectHomeScreen.location(
                                      projectId,
                                    ),
                                  );
                                }
                              },
                            );
                          }),
                    ],
                  ],
                );
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          goToAuthScreen(context);
        },
        child: const Icon(Icons.person_2_outlined),
      ),
    );
  }
}
