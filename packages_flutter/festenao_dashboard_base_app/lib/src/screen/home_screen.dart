import 'package:festenao_admin_base_app/l10n/app_intl.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_rpd.dart';
import 'package:festenao_dashboard_base_app/src/provider/auth_screen.dart';
import 'package:festenao_dashboard_base_app/src/provider/festenao_user_projects.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/screen/pending_email_invites_view.dart';
import 'package:festenao_dashboard_base_app/src/screen/project_leading.dart';
import 'package:festenao_dashboard_base_app/src/screen/projects_access_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:festenao_theme/design.dart';
import 'package:festenao_theme/kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tkcms_common/tkcms_auth.dart';

/// The home page of a dashboard app, on the festenao kit: who is signed in
/// (an account button in the app bar), the pending email invites, the
/// entries (projects, logs, debug in a debug build) and the projects of the
/// signed in user; a sign in card when signed out.
class DashboardHomePage extends ConsumerWidget {
  static String get routeName => 'home';

  static String get routeLocation => '/';

  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var authStateValue = ref.watch(rpdTkCmsFbIdentityBlocStateProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(intl.dashboardHomeTitle),
        actions: [
          IconButton(
            tooltip: intl.dashboardAccount,
            icon: const Icon(Icons.person_2_outlined),
            onPressed: () {
              goToAuthScreen(context);
            },
          ),
        ],
      ),
      body: authStateValue.maybeWhen(
        orElse: () => const SizedBox.shrink(),
        data: (authState) => _HomeBody(identity: authState.identity),
      ),
    );
  }
}

/// The page, for [identity] (null when signed out).
class _HomeBody extends StatelessWidget {
  final TkCmsFbIdentity? identity;

  const _HomeBody({required this.identity});

  @override
  Widget build(BuildContext context) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var identity = this.identity;
    var signedIn = identity != null;
    return FkPage(
      maxWidth: 960,
      children: [
        FkHeader(
          title: intl.dashboardWelcome,
          subtitle: identity == null
              ? intl.notSignedInInfo
              : intl.userSignedInInfo(
                  identity.user?.email ?? identity.userOrAccountId,
                ),
        ),
        // Checked on the app start and after each sign in.
        if (signedIn) const PendingEmailInvitesView(),
        if (!signedIn) ...[
          FkCard(
            child: FkEmpty(
              icon: Icons.login,
              message: intl.notSignedInInfo,
              action: FilledButton.icon(
                onPressed: () {
                  goToAuthScreen(context);
                },
                icon: const Icon(Icons.login),
                label: Text(intl.signInButtonLabel),
              ),
            ),
          ),
          if (kDebugMode) const SizedBox(height: FestenaoSpace.xl),
        ],
        if (signedIn || kDebugMode)
          FkListCard(
            children: [
              if (signedIn) ...[
                FkRow(
                  leading: const FkIconBox(Icons.folder_outlined),
                  title: intl.projectsTitle,
                  subtitle: intl.projectsSubtitle,
                  trailing: Icon(Icons.chevron_right, color: t.ink3),
                  onTap: () {
                    context.pushPath(projectsAccessPath);
                  },
                ),
                FkRow(
                  leading: const FkIconBox(Icons.analytics_outlined),
                  title: intl.dashboardLogs,
                  subtitle: intl.dashboardLogsDetail,
                  trailing: Icon(Icons.chevron_right, color: t.ink3),
                  onTap: () {
                    context.pushPath(dashboardLogsPath);
                  },
                ),
              ],
              if (kDebugMode)
                FkRow(
                  leading: FkIconBox(Icons.bug_report_outlined, color: t.muted),
                  title: intl.dashboardDebug,
                  trailing: Icon(Icons.chevron_right, color: t.ink3),
                  onTap: () {
                    context.pushNamed('debug');
                  },
                ),
            ],
          ),
        if (signedIn) ...[
          const SizedBox(height: FestenaoSpace.xl),
          FkSectionTitle(intl.dashboardYourProjects),
          _UserProjects(userId: identity.userOrAccountId),
        ],
      ],
    );
  }
}

/// The projects of the user [userId] in the local projects database, a row
/// each opening the project home.
class _UserProjects extends ConsumerWidget {
  final String userId;

  const _UserProjects({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var intl = festenaoAdminAppIntl(context);
    var t = context.festenao;
    var projects = ref.watch(rpdUserProjectsProvider(userId)).value;
    if (projects == null) {
      return const FkCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(),
        ),
      );
    }
    if (projects.isEmpty) {
      return FkCard(
        child: FkEmpty(
          icon: Icons.folder_open_outlined,
          message: intl.projectsNone,
        ),
      );
    }
    return FkListCard(
      children: [
        for (var project in projects)
          FkRow(
            leading: ProjectLeading(project: project),
            title: project.name.v ?? project.uid.v ?? '',
            subtitle: project.name.v == null ? null : project.uid.v,
            badges: [
              FkStatusPill(
                dashboardProjectRole(project).label(intl),
                status: dashboardProjectRole(project).status,
              ),
            ],
            trailing: Icon(Icons.chevron_right, color: t.ink3),
            onTap: () {
              var projectId = project.uid.v;
              if (projectId != null) {
                context.pushPath(
                  dashboardProjectPath,
                  parameters: {DashboardRouteParams.projectId: projectId},
                );
              }
            },
          ),
      ],
    );
  }
}
