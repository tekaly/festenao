---
name: festenao-common-flutter-quizz
description: >-
  Use when building the Flutter screens of a festenao quizz (admin control,
  tv display, player device) with festenao_common_flutter/festenao_quizz_flutter.dart:
  QuizzStateNowBuilder and QuizzPeriodicBuilder over a QuizPlayerController,
  QuizzControlWidget / QuizzStatusWidget, the progress widgets
  (QuizzProgressIndicator, QuizzFiniteProgressIndicator,
  QuizzStepProgressIndicator, QuizzProgressTimeWidget, QuizzRoundedText),
  QuizzTimeWidget, QuizzQuestionWidget / QuizzAnswerButton, the results
  (QuizzTopPlayersWidget, QuizzPodiumWidget, QuizzResultPodiumWidget,
  quizzFillTo3Players), QuizzValidationWidget / QuizzToValidatePlayerWidget,
  the display name helpers (quizzFixDisplayNameString,
  quizzHideDisplayNameString, quizzGetPlayerDisplayName) and the prefs
  backed QuizzPrefsServicePrefs / quizzPrefsGetOrCreateDeviceId.
---

# Festenao quizz widgets (festenao_common_flutter)

`festenao_quizz_flutter.dart` is the widget layer of the festenao quizz (a
timed multiple choice quiz, see the `festenao-common-quizz` skill of
`festenao_common` for the models, the firestore layer and the
`QuizPlayerController` state machine). It re-exports
`festenao_common/festenao_quizz.dart` and adds the widgets the admin, tv and
player screens are assembled from.

## Guidelines

* Import `package:festenao_common_flutter/festenao_quizz_flutter.dart`
  (same git dependency as `festenao-common-flutter-setup`); it re-exports
  `festenao_quizz.dart`, so `QuizPlayerController`, `QuizzFirestoreDatabase`,
  `QuizzTimeService`, `FsQuiz`, `FsQuizPlayer`, `quizzFormatMs`... need no
  second import. The prefs service needs `package:tekartik_app_prefs/app_prefs.dart`.
* Everything time dependent is derived from a `QuizPlayerController`
  (`databaseService:`, `quizId:`, `prefs:`, `controllerId:`, `apiClient:`,
  `timeService:`): `QuizzStateNowBuilder(controller:, builder:, period:)`
  rebuilds on every state change and every `period` (100 ms) with the
  `QuizPlayerStateNow` of `controller.timeService.timestamp` (null until the
  quiz and its status are read). Branch on it: `isIdle`, `isPre`
  (`getRemainingPreMs()`), `questionIndex` (null between questions or when
  not playing), `getQuestionAnswerRemainingMs(index)`, `getQuestionAt(index)`,
  `questionCount`, `isPost`, `isDoneOrArchived`, `isCancelled`, `isPaused`.
  `QuizzPeriodicBuilder(duration:, builder:)` is the bare periodic rebuild.
* Admin side: `QuizzControlWidget(controller:, auto:)` is the control bar
  (previous, pause, resume, next, compute the ranks now, cancel in debug)
  above `QuizzStatusWidget(stateNow:, auto:, controller:)`, the status line
  (waiting, qr code display countdown, question n with its remaining time,
  pause, end with the score computer progress, ranks computed). With
  `auto: true` the status widget calls `waitAndComputePlayerRanks` once the
  quiz is over.
* Time: `QuizzTimeWidget(timeService:, style:)` shows the server synchronized
  clock (`hh:mm:ss`), waiting up to 3 s for `timeService.fixedOnce`.
  Progress of a step from a `QuizProgressController(startMs:, endMs:,
  pausedMs:)`: `QuizzStepProgressIndicator(controller:, timeService:)`
  (paused bar or animated one, keyed on `startMs` so it restarts per step),
  `QuizzFiniteProgressIndicator(onEnd:, controller:, timeService:)` (calls
  `onEnd` at the end), `QuizzProgressTimeWidget(controller:, timeService:,
  fontSize:, width:, shadowColor:)` (remaining `mm:ss` in a
  `QuizzRoundedText`, hidden while paused outside debug).
* Player side: `QuizzQuestionWidget(question:, languageCode:,
  selectedAnswerId:, correctAnswerId:, onAnswer:, header:)` shows the text
  (`textForLanguageCode`) and one `QuizzAnswerButton` per answer,
  highlighted when selected, green/red once `correctAnswerId` is given;
  `onAnswer` null disables the buttons (time is up). `question` is any
  `CvQuestionMixin`, e.g. `stateNow.getQuestionAt(index)`.
* Results: `QuizzTopPlayersWidget(database:, quizId:, limit:, showNames:)`
  streams `orderedPlayersNoValidityStream` as a list (names hidden until
  validated unless `showNames`); `QuizzResultPodiumWidget(database:,
  quizId:, avatars:)` waits for the ranks (`quizStatusStream` then
  `rankedPlayersStream`) and shows `QuizzPodiumWidget(players:, nameColor:,
  colors:)`, the 2nd / 1st / 3rd columns (`QuizzPodiumColumnWidget`) sized
  from the available height; `quizzFillTo3Players(players, quizId,
  avatars:)` pads to three with placeholder players.
* Validation: `QuizzValidationWidget(database:, timeService:, quiz:, onEnd:,
  advancedMode:)` lists the players best first with a validate toggle each
  (`QuizzToValidatePlayerWidget`, writes `validatePlayer`) and a "validate
  the 3 first" button, under a progress bar of `quiz.validationDelayMsOrDefault`
  calling `onEnd` when over.
* Names: `quizzFixDisplayNameString` (trimmed, capitalized, `P` when
  empty), `quizzHideDisplayNameString` (`A…`), `quizzGetPlayerDisplayName(player)`
  (fixed when `validity.v == quizPlayerValidityValid`, hidden otherwise).
* Prefs: `QuizzPrefsServicePrefs(prefs:)` is the `QuizzPrefsService`
  persisted in a `Prefs` (`tekartik_app_prefs`), keyed by the current quiz
  (`prefsSetQuizId(id)` discards the local status and copy of another
  quiz); also `prefsGetLastUsername` / `prefsSetLastUsername`,
  `prefsGetLastTimeOffsetMs` / `prefsSetLastTimeOffsetMs`.
  `quizzPrefsGetOrCreateDeviceId(prefs)` is the stable device id used as
  the player `controllerId`. Tests use `QuizzPrefsServiceMemory()`.

## Examples

### Player prefs and controller

```dart
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:tekartik_app_prefs/app_prefs.dart';

Future<QuizPlayerController> openPlayerController({
  required QuizzFirestoreDatabase database,
  required QuizzApiClient apiClient,
  required QuizzTimeService timeService,
  required String quizId,
}) async {
  var prefs = await getPrefsFactory(
    packageName: 'com.example.quizz',
  ).openPreferences('quizz');
  var prefsService = QuizzPrefsServicePrefs(prefs: prefs)
    ..prefsSetQuizId(quizId);
  return QuizPlayerController(
    databaseService: database,
    quizId: quizId,
    prefs: prefsService,
    controllerId: quizzPrefsGetOrCreateDeviceId(prefs),
    apiClient: apiClient,
    timeService: timeService,
  );
}
```

### Admin control screen

```dart
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:flutter/material.dart';

class QuizzAdminScreen extends StatelessWidget {
  final QuizPlayerController controller;

  const QuizzAdminScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz ${controller.quizId}'),
        actions: [
          Center(
            child: QuizzTimeWidget(timeService: controller.timeService),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          QuizzControlWidget(controller: controller, auto: true),
          Expanded(
            child: QuizzTopPlayersWidget(
              database: controller.databaseService,
              quizId: controller.quizId,
              limit: 10,
              showNames: true,
            ),
          ),
        ],
      ),
    );
  }
}
```

### Player question view

```dart
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:flutter/material.dart';

class QuizzPlayerQuestionView extends StatelessWidget {
  final QuizPlayerController controller;
  final String? selectedAnswerId;
  final void Function(String answerId) onAnswer;

  const QuizzPlayerQuestionView({
    super.key,
    required this.controller,
    required this.selectedAnswerId,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return QuizzStateNowBuilder(
      controller: controller,
      builder: (context, stateNow) {
        if (stateNow == null) {
          return const Center(child: CircularProgressIndicator());
        }
        var index = stateNow.questionIndex;
        if (index == null) {
          // Idle, qr code display, pause between questions, end...
          return QuizzStatusWidget(
            stateNow: stateNow,
            auto: false,
            controller: controller,
          );
        }
        var remainingMs = stateNow.getQuestionAnswerRemainingMs(index);
        return Column(
          children: [
            Text(quizzFormatMs(remainingMs)),
            QuizzQuestionWidget(
              question: stateNow.getQuestionAt(index),
              header: '${index + 1} / ${stateNow.questionCount}',
              languageCode: 'fr',
              selectedAnswerId: selectedAnswerId,
              onAnswer: remainingMs > 0 ? onAnswer : null, // time is up
            ),
          ],
        );
      },
    );
  }
}
```

### Tv end of quiz: validation then podium

```dart
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:flutter/material.dart';

class QuizzTvEndView extends StatefulWidget {
  final QuizzFirestoreDatabase database;
  final QuizzTimeService timeService;
  final FsQuiz quiz;

  const QuizzTvEndView({
    super.key,
    required this.database,
    required this.timeService,
    required this.quiz,
  });

  @override
  State<QuizzTvEndView> createState() => _QuizzTvEndViewState();
}

class _QuizzTvEndViewState extends State<QuizzTvEndView> {
  var _validationOver = false;

  @override
  Widget build(BuildContext context) {
    if (!_validationOver) {
      return QuizzValidationWidget(
        database: widget.database,
        timeService: widget.timeService,
        quiz: widget.quiz,
        advancedMode: true,
        onEnd: () => setState(() => _validationOver = true),
      );
    }
    return SizedBox(
      height: 400,
      child: QuizzResultPodiumWidget(
        database: widget.database,
        quizId: widget.quiz.id,
      ),
    );
  }
}
```

### A step countdown

```dart
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:flutter/material.dart';

/// A 15 s countdown starting now, with its bar.
Widget stepCountdown(QuizzTimeService timeService) {
  var now = timeService.timestampMs;
  var controller = QuizProgressController(startMs: now, endMs: now + 15000);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      QuizzProgressTimeWidget(
        controller: controller,
        timeService: timeService,
        fontSize: 32,
        width: 140,
        shadowColor: Colors.black26,
      ),
      QuizzStepProgressIndicator(
        controller: controller,
        timeService: timeService,
      ),
    ],
  );
}
```

## Common mistakes

* Reading `DateTime.now()` instead of `timeService.timestamp`: every
  countdown drifts from the other devices.
* Calling `controller.next(...)`, `pause`, `resume` with anything but
  `controller.timeService.timestamp`.
* Rebuilding on a `Timer` of your own around `QuizzStateNowBuilder` (it
  already ticks every `period`).
* Showing player names before validation (`quizzGetPlayerDisplayName`
  hides them on purpose).
