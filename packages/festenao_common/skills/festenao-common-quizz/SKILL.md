---
name: festenao-common-quizz
description: >-
  Use when an app built on festenao runs a timed multiple choice quiz: the
  festenao_quizz.dart models (FsQuestion, FsQuiz, FsQuizStatus, FsQuizPlayer,
  FsSession, the gd goodies), QuizzFirestoreDatabase under a project's
  data/quizz document, the QuizPlayerController state machine
  (QuizRunnerState, QuizPlayerStateNow) driving the admin, tv and player
  sides, the quizz/send_result api (QuizzApiClient, QuizzServerHandler), the
  server synchronized QuizzTimeService, the QuizzPrefsService local player
  status, the festenao_common_flutter widgets and the dashboard/user plus
  screens.
---

# festenao_common quizz

A quiz is a timed sequence of multiple choice questions. Two flavors share
the models and the state machine: a **tv** quiz, displayed on a screen and
driven by an admin, every player answering the same question at the same
time, the 3 first players being validated and ranked at the end; a **gd**
quiz, played alone on a device with a random question set and a goodie to
win. The code was extracted from the quizz2023 apps into `festenao_common`
(pure dart), `festenao_common_flutter` (widgets) and
`festenao_dashboard_base_app` (admin screens and riverpod providers), the
user plus app of festenaoprv being the player side.

## Guidelines

* Imports: `package:festenao_common/festenao_quizz.dart` (everything pure
  dart), `package:festenao_common_flutter/festenao_quizz_flutter.dart` (the
  widgets, re-exporting the former), `package:festenao_dashboard_base_app/
  provider.dart` (the riverpod providers) and `router.dart`
  (`DashboardQuizzRouteModule`, `quizzHomePath`, `quizzControlPath`,
  `quizzTvPath`). Never import `src/`.
* Data lives under a root document, by default the project's
  `app/<app>/project/<projectId>/data/quizz`
  (`festenaoProjectQuizzRootDocument(app:, projectId:)`): `questions/{id}`
  (`FsQuestion`, text and answers in en/fr, `correctAnswerId`, `tags`,
  `lastPlayedTimestamp` used to pick the least recently played),
  `quizzes/{id}` (`FsQuiz`, the picked questions with their correct answer
  **encrypted** with the quiz `uid`, the config delays), its
  `infos/status` (`FsQuizStatus`: `idle`, `playing`, `paused`, `cancelled`,
  `done`, `archived`, `startTimestamp`, `pausedStartTimestamp`,
  `playersCount`), its `players/{id}` (`FsQuizPlayer`, server written),
  `sessions/{id}` (`FsSession.activeQuizId`, the gd `players` and goodies),
  `archived_quizzes` and `infos/quiz_config` (`FsQuizConfig`). Being in the
  project `data` subtree, the project rules apply: writers write, members
  read, anyone reads when the project is public (what a player needs).
* `QuizzFirestoreDatabase(firestore:, rootDocument:)` is the only firestore
  layer: `addQuestion`/`setQuestion`/`deleteQuestion`, `questionsStream`,
  `createTvQuiz(now:, config:, sessionId:)` (picks and marks the questions,
  writes the quiz and an `idle` status in one transaction),
  `makeQuizPreActive`, `startQuiz`/`startActiveQuiz(now:)`, `pauseQuiz`,
  `resumeQuiz` (shifts `startTimestamp` by the pause), `quizOffset(ms:)`
  (previous/next), `cancelQuiz`, `validatePlayers`, `computePlayersRanks`
  then `quizUpdatePlayerCountAndMarkAsDone`, `archiveQuiz`, `deleteQuiz`,
  `cronCleanup()` (delete after 28 days, archive after a day), and the gd
  `createGdQuiz`/`txnPlayerWinRandomGoodie`. Register the models with
  `initQuizzBuilders()` (the database and handler do it).
* Timing is derived, never stored per question: `QuizRunnerStateCache`
  computes the question starts from the config (`preDelayMs`, then
  `answerDelayMs` + `pauseDelayMs` per question), `QuizRunnerState` pairs it
  with the status and `state.now(dateTime)` gives the `QuizPlayerStateNow`
  view: `isIdle`/`isPre`/`questionIndex`/`isPost`/`isDone`, the remaining
  and elapsed ms, and a `QuizProgressController` per step for the widgets.
  Every device must use the same clock: `QuizzTimeService(timestampProvider:
  apiService)..run()` measures the offset with the server (any
  `TkCmsApiServiceBaseV2` is a `TkCmsTimestampProvider`), `.local()` in
  tests.
* `QuizPlayerController(databaseService:, quizId:, controllerId:, prefs:,
  apiClient:, timeService:)` follows the quiz and its status and exposes
  `stateValueStream`; `AdminQuizPlayerController` (control screen, tv) adds
  `startActiveQuiz`, `pause`/`resume`/`previous`/`next`,
  `waitAndComputePlayerRanks(now, auto:)` (waits for the results, the
  validation unless `auto`, then ranks), `UserQuizPlayerController` (player)
  adds `sendResult(now)` whose stream ends with a
  `SendResultControllerStateRank` (tv) or `SendResultControllerStateWon`
  (gd). Dispose them.
* The player keeps its progress in a `QuizzPrefsService`
  (`PrefsQuizLocalStatus`: username, answers, sent player id, rank;
  `PrefsQuizLocalCopy`: the gd question set): `QuizzPrefsServiceMemory` for
  the admin/tv/tests, `QuizzPrefsServicePrefs(prefs:)` (flutter, keyed by
  `prefsSetQuizId`) on a device, `quizzPrefsGetOrCreateDeviceId(prefs)` for
  the controller id.
* Results go through the api, never straight to firestore:
  `QuizzApiClient(apiService:, projectId:).sendQuizResult(query)` sends an
  `ApiQuizzSendResultQuery` (signed by its `toMap`, `localTimestamp` less
  than 30 minutes old) as `quizz/send_result`; server side
  `QuizzServerHandler(options: QuizzServerHandlerOptions(firestore:,
  rootDocumentResolver: festenaoQuizzRootDocumentResolver(app:)))` scores it
  from the quiz correct answers (or the client `correct` flags for gd, with
  a goodie draw) and writes the player, the same result twice giving the
  same player id. Add it to a server app's `onCommand` through
  `onCommandOrNull` (`FestenaoServerAppTest`, `festenao_dartff` and
  `festenaoprv_dartff` have it).
* The correct answers are encrypted with `quizzModelEncryptionCodec`, an
  app sets its own 32 characters password once with
  `quizzSetModelEncryptionPassword` before any quiz is created (changing it
  breaks the existing quizzes).
* Flutter: `QuizzStateNowBuilder(controller:, builder:)` rebuilds on every
  state change and every 100 ms; `QuizzControlWidget`/`QuizzStatusWidget`
  (admin bar), `QuizzQuestionWidget` (answers as buttons, `onAnswer`,
  `correctAnswerId` reveals), `QuizzProgressTimeWidget`/
  `QuizzStepProgressIndicator` (a `QuizProgressController` plus the time
  service), `QuizzValidationWidget` (players to validate),
  `QuizzTopPlayersWidget` and `QuizzResultPodiumWidget` (the ranking).
* Dashboard: `DashboardQuizzRouteModule` mounts `/project/:project_id/quizz`
  (questions and quizzes), `question_create`, `question/:question_id`,
  `quiz/:quiz_id` (control, qr code, validation) and `quiz/:quiz_id/tv`
  under the project route; the providers (`quizzDatabaseProvider(projectId)`,
  `quizzAdminControllerProvider((projectId:, quizId:))`,
  `quizzUserControllerProvider`, `quizzTimeServiceProvider`,
  `quizzApiServiceProvider` defaulting to the global festenao api service,
  `quizzUserPlayUriBuilderProvider` for the player link) are in
  `provider.dart`. The player screen (`QuizzPlayScreen`,
  `/project/:project_id/quizz/:quiz_id`) is in `festenaoprv_user_plus_app`.
* Tests: `test/quizz/*` in `festenao_common` (memory firestore and the
  memory server), `testQuizzServerGroup(() async => QuizzTestContext(...))`
  (`package:festenao_common/test/quizz_server_test_runner.dart`) runs the
  api tests against any server, the dartff emulator tests include it;
  `newQuizzTestQuestion1()`/`newQuizzTestGoodiesConfig()`
  (`test/quizz_test_fixtures.dart`) are the fixtures.
