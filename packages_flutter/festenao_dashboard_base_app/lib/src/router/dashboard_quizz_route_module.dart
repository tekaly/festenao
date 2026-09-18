import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_scope.dart';
import 'package:festenao_dashboard_base_app/src/screen/quizz/quizz_control_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/quizz/quizz_home_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/quizz/quizz_question_edit_screen.dart';
import 'package:festenao_dashboard_base_app/src/screen/quizz/quizz_tv_screen.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';

/// The quizz feature of a project: its questions and quizzes, the admin
/// control of a quiz and its tv display, mounted under
/// [dashboardProjectPath].
///
/// The screens read the project id from the scope their route builds and
/// the question/quiz ids from the location.
class DashboardQuizzRouteModule implements NestedFeatureRouteModule {
  @override
  String get moduleId => 'dashboard_quizz';

  @override
  String get parentRouteName => dashboardProjectPath.name!;

  @override
  List<RouteBase> get routes => [
    quizzHomePath.goRoute(
      builder: (context, state) =>
          dashboardProjectScope(state, child: const QuizzHomeScreen()),
      routes: [
        quizzQuestionCreatePath.goRoute(
          builder: (context, state) => dashboardProjectScope(
            state,
            child: const QuizzQuestionEditScreen(questionId: null),
          ),
        ),
        quizzQuestionEditPath.goRoute(
          builder: (context, state) => dashboardProjectScope(
            state,
            child: QuizzQuestionEditScreen(
              questionId: state.pathParameter(DashboardRouteParams.questionId),
            ),
          ),
        ),
        quizzControlPath.goRoute(
          builder: (context, state) => dashboardProjectScope(
            state,
            child: QuizzControlScreen(
              quizId: state.pathParameter(DashboardRouteParams.quizId),
            ),
          ),
          routes: [
            quizzTvPath.goRoute(
              builder: (context, state) => dashboardProjectScope(
                state,
                child: QuizzTvScreen(
                  quizId: state.pathParameter(DashboardRouteParams.quizId),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ];
}
