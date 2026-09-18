/// The quizz providers: the firestore database of a project's quizz data,
/// the questions and quizzes streams, the server synchronized clock, the
/// api client and the admin/user controllers of a quiz.
///
/// The quizz data of a project lives at
/// `app/<app>/project/<projectId>/data/quizz`
/// ([festenaoProjectQuizzRootDocument]).
library;

import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:festenao_dashboard_base_app/src/provider/firebase_app_rpd.dart';
import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';
import 'package:tkcms_common/tkcms_api.dart';

/// The api service the quizz feature sends the player results through, null
/// when the app has none (the admin side works without it, a player cannot
/// send its result).
///
/// Defaults to the global festenao api service; an app overrides it with its
/// own.
final quizzApiServiceProvider = Provider<TkCmsApiServiceBaseV2?>(
  (ref) => globalFestenaoApiServiceOrNull,
  name: 'quizzApiService',
);

/// The server synchronized clock, local when there is no api service.
final quizzTimeServiceProvider = Provider<QuizzTimeService>((ref) {
  var service = QuizzTimeService(
    timestampProvider: ref.watch(quizzApiServiceProvider),
  )..run();
  ref.onDispose(service.dispose);
  return service;
}, name: 'quizzTimeService');

/// The id of this device as a quiz controller, one per app run.
final quizzDeviceIdProvider = Provider<String>(
  (ref) => quizzGenerateDeviceId(),
  name: 'quizzDeviceId',
);

/// The app id the quizz data is under.
///
/// The one of [festenaoAppFlavorContextProvider], falling back to the global
/// festenao firestore database for the apps that do not override it.
final quizzAppIdProvider = Provider<String>((ref) {
  try {
    return ref.watch(festenaoAppFlavorContextProvider).appId;
  } catch (_) {
    var app = globalFestenaoFirestoreDatabaseOrNull?.app;
    if (app == null) {
      rethrow;
    }
    return app;
  }
}, name: 'quizzAppId');

/// The quizz database of a project.
final quizzDatabaseProvider = Provider.family<QuizzFirestoreDatabase, String>((
  ref,
  projectId,
) {
  var firestore = ref.watch(rpdFirestoreProvider);
  var app = ref.watch(quizzAppIdProvider);
  return QuizzFirestoreDatabase(
    firestore: firestore,
    rootDocument: festenaoProjectQuizzRootDocument(
      app: app,
      projectId: projectId,
    ),
  );
}, name: 'quizzDatabase');

/// The quizz api client of a project, null without api service.
final quizzApiClientProvider = Provider.family<QuizzApiClient?, String>((
  ref,
  projectId,
) {
  var apiService = ref.watch(quizzApiServiceProvider);
  if (apiService == null) {
    return null;
  }
  return QuizzApiClient(apiService: apiService, projectId: projectId);
}, name: 'quizzApiClient');

/// The questions of a project.
final quizzQuestionsProvider = StreamProvider.family<List<FsQuestion>, String>(
  (ref, projectId) =>
      ref.watch(quizzDatabaseProvider(projectId)).questionsStream(),
  name: 'quizzQuestions',
);

/// One question of a project.
final quizzQuestionProvider =
    StreamProvider.family<FsQuestion, ({String projectId, String questionId})>((
      ref,
      key,
    ) {
      var db = ref.watch(quizzDatabaseProvider(key.projectId));
      return db.fsQuestion(key.questionId).onSnapshot(db.firestore);
    }, name: 'quizzQuestion');

/// The quizzes of a project, most recent first.
final quizzQuizzesProvider = StreamProvider.family<List<FsQuiz>, String>(
  (ref, projectId) =>
      ref.watch(quizzDatabaseProvider(projectId)).quizStream(limit: 50),
  name: 'quizzQuizzes',
);

/// The status of a quiz.
final quizzQuizStatusProvider =
    StreamProvider.family<FsQuizStatus, ({String projectId, String quizId})>(
      (ref, key) => ref
          .watch(quizzDatabaseProvider(key.projectId))
          .quizStatusStream(key.quizId),
      name: 'quizzQuizStatus',
    );

/// The admin (controller) side of a quiz, shared by the control and tv
/// screens of that quiz, disposed once neither is mounted.
final quizzAdminControllerProvider = Provider.autoDispose
    .family<AdminQuizPlayerController, ({String projectId, String quizId})>((
      ref,
      key,
    ) {
      var controller = AdminQuizPlayerController(
        databaseService: ref.watch(quizzDatabaseProvider(key.projectId)),
        quizId: key.quizId,
        prefs: QuizzPrefsServiceMemory(),
        controllerId: ref.watch(quizzDeviceIdProvider),
        apiClient: ref.watch(quizzApiClientProvider(key.projectId)),
        timeService: ref.watch(quizzTimeServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    }, name: 'quizzAdminController');

/// The local prefs of a player (its answers survive a reload).
final quizzPrefsServiceProvider = FutureProvider<QuizzPrefsServicePrefs>((
  ref,
) async {
  String? packageName;
  try {
    packageName = ref.watch(festenaoAppFlavorContextProvider).packageName;
  } catch (_) {}
  var prefsFactory = getPrefsFactory(packageName: packageName);
  var prefs = await prefsFactory.openPreferences('quizz_prefs.db');
  return QuizzPrefsServicePrefs(prefs: prefs);
}, name: 'quizzPrefsService');

/// The player side of a quiz, disposed once the play screen is left.
final quizzUserControllerProvider = FutureProvider.autoDispose
    .family<UserQuizPlayerController, ({String projectId, String quizId})>((
      ref,
      key,
    ) async {
      var prefs = await ref.watch(quizzPrefsServiceProvider.future);
      prefs.prefsSetQuizId(key.quizId);
      var controller = UserQuizPlayerController(
        databaseService: ref.watch(quizzDatabaseProvider(key.projectId)),
        quizId: key.quizId,
        prefs: prefs,
        controllerId: quizzPrefsGetOrCreateDeviceId(prefs.prefs),
        apiClient: ref.watch(quizzApiClientProvider(key.projectId)),
        timeService: ref.watch(quizzTimeServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    }, name: 'quizzUserController');

/// Builds the link a player opens to play a quiz (the qr code of the control
/// and tv screens).
typedef QuizzUserPlayUriBuilder =
    Uri Function({required String projectId, required String quizId});

/// The player link builder, `<origin>/project/<projectId>/quizz/<quizId>` on
/// the current host by default; a dashboard app hosted apart from its player
/// app overrides it.
final quizzUserPlayUriBuilderProvider = Provider<QuizzUserPlayUriBuilder>(
  (ref) =>
      ({required projectId, required quizId}) => Uri.base.replace(
        path: '/project/$projectId/quizz/$quizId',
        query: null,
        fragment: null,
      ),
  name: 'quizzUserPlayUriBuilder',
);
