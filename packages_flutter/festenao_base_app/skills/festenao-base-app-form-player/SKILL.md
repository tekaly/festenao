---
name: festenao-base-app-form-player
description: >-
  Use when playing a form or survey to the user with the form player screens
  of festenao_base_app: FormScreenControllerBase(player:) and its
  goToFormStartScreen / goToQuestionScreen / goToQuestionOrEndScreen /
  goToFormEndScreen, the TkFormPlayer it drives (TestFormPlayer or a
  TkFormPlayerBase subclass, TkFormPlayerQuestion with
  TkFormPlayerQuestionTextOptions / ChoiceOptions / IntOptions /
  InformationOptions, TkFormPlayerQuestionChoice, TkFormPlayerFormBase,
  TkFormPlayerQuestionAnswer), custom screens (newStartScreen /
  newQuestionScreen / newEndScreen, FormStartScreen, QuestionScreen,
  FormEndScreen, ThankYouScreen, AppScaffold), the blocs (FormPlayerBloc,
  QuestionPlayerScreenBloc, globalSurveyPlayerFormBloc, SurveyPlayerFormBloc,
  gAppBloc / initFormBloc) and the debug entries goToUserDebugScreen
  (form/form.dart) and startScreenDebugOnInit. Not the festenao data layer.
---

# festenao_base_app form player

A form is a `TkFormPlayer` (`festenao_common/form/tk_form.dart`): a
`TkFormPlayerForm`, its `TkFormPlayerQuestion`s and the answers, with
`shouldSkip` deciding which questions are shown. `festenao_base_app` ships
the screens that walk through it, start, one screen per question, end, all
reached from a `FormScreenController` holding the player.

```dart
import 'package:festenao_base_app/form/src/screen/form_screen_controller.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_test_helper.dart';
import 'package:flutter/material.dart';

Future<void> playOneQuestion(BuildContext context) async {
  var player = TestFormPlayer(
    id: 'demo',
    form: TkFormPlayerFormBase(id: 'f1', name: 'Demo'),
    questions: [
      TkFormPlayerQuestion(
        id: 'q1',
        text: 'Your name?',
        options: TkFormPlayerQuestionTextOptions(),
      ),
    ],
  );
  await FormScreenControllerBase(player: player).goToFormStartScreen(context);
}
```

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    festenao_base_app:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_base_app
  ```
* Imports: the only facade, `package:festenao_base_app/form/form.dart`,
  exports `goToUserDebugScreen`. The player screens are imported by file,
  as the apps do: `form/src/screen/form_screen_controller.dart`
  (`FormScreenController`, `FormScreenControllerBase`, the content paths),
  `form/src/screen/form_bloc.dart` (`FormPlayerBloc`),
  `form/src/screen/form_screen.dart` (`SurveyPlayerFormBloc`,
  `SurveyFormPlayer`, `FormScreenStateBase`),
  `form/src/screen/form_question_screen_bloc.dart`
  (`QuestionPlayerScreenBloc`), `form/src/screen/start_screen.dart`
  (`startScreenDebugOnInit`, `DebugOnInitState`),
  `form/src/screen/debug_screen.dart` (`initFormBloc`, `UserDebugScreen`),
  `form/src/screen/thank_you_screen.dart` (`ThankYouScreen`,
  `goToThankYouScreen`), `form/src/view/app_scaffold.dart` (`AppScaffold`),
  `form/src/app/app_bloc.dart` (`AppBloc`, `gAppBloc`). The player model is
  `package:festenao_common/form/tk_form.dart`, `TestFormPlayer` is in
  `package:festenao_common/form/tk_form_test_helper.dart`.
* Build the player: `TestFormPlayer(id:, form: TkFormPlayerFormBase(id:,
  name:), questions: [...])` keeps the answers in memory and skips nothing.
  For anything else extend `TkFormPlayerBase` and override `setAnswer`
  (persist) and `shouldSkip(index)` (conditions), the way `SurveyFormPlayer`
  does on top of the sembast `DbSurvey`.
* Questions: `TkFormPlayerQuestion(id:, text:, options:, hint:, title:)`.
  Options: `TkFormPlayerQuestionTextOptions(emptyAllowed:)`,
  `TkFormPlayerQuestionChoiceOptions(choices: [TkFormPlayerQuestionChoice(id:,
  text:, allowOther:)], multi:, emptyAllowed:)`,
  `TkFormPlayerQuestionIntOptions(presets:, min:, max:, emptyAllowed:)`,
  `TkFormPlayerQuestionInformationOptions()` (no answer). With
  `emptyAllowed` false (the default) the next button stays disabled until
  there is an answer. Answers are `TkFormPlayerQuestionAnswer` (`textValue`,
  `intValue`, `choiceId`, `choiceIds` for `multi`).
* Navigation, all on `FormScreenControllerBase(player:)`:
  `goToFormStartScreen(context)` pushes the start screen (form name, start
  button) with a `FormPlayerBloc`; `goToQuestionScreen(context,
  questionIndex:)` pushes a question with a `QuestionPlayerScreenBloc`
  (no animation, route name `question=<i>`, `FormQuestionContentPath`);
  `goToQuestionOrEndScreen(context, questionIndex:)` goes to the end screen
  from `player.questionCount`; `goToFormEndScreen(context)`. The question
  screen itself moves to the next non skipped question, so the caller only
  starts the flow.
* Custom look: subclass `FormScreenControllerBase` and override
  `newStartScreen()`, `newQuestionScreen()`, `newEndScreen()` to return your
  widgets; the base `goTo` methods still provide the blocs
  (`BlocProvider.of<FormPlayerBloc>(context)` on the start and end screens,
  `BlocProvider.of<QuestionPlayerScreenBloc>(context)` on a question:
  `questionIndex`, `player`, `state` with the question and its answer).
  `FormScreenStateBase<T>` is a state base holding the controller.
* `AppScaffold(appBar:, body:, floatingActionButton:)` is the scaffold of
  the shipped screens: a 600x800 rounded "phone" card centered on black when
  the window exceeds 640x840, a plain scaffold otherwise;
  `resizeToAvoidBottomInset` on.
* Survey mode: `initFormBloc(databaseFactory:, appFlavorContext:)` creates
  `gAppBloc` (`AppBloc` on a sembast `LocalDatabase`, survey id `test`) and
  `SurveyPlayerFormBloc.newPlayer()` builds a `SurveyFormPlayer` from
  `gAppBloc.dbSurveyVS` (`DbSurvey`, `festenao_common/form/tk_form_db.dart`).
  A `QuestionPlayerScreenBloc` built without `player:` falls back to
  `globalSurveyPlayerFormBloc.player`: always pass the player unless you are
  in that flow, or the screen waits for a survey bloc that never emits.
* Debug: `goToUserDebugScreen(context)` pushes the menu of sample forms
  (one question, choices, multi question, thank you screen); the start
  screen shows a settings FAB to it in debug mode.
  `startScreenDebugOnInit = DebugOnInitState((context) async {...})` runs
  once when the first start screen is built (jump to a question while
  developing).
* The shipped screens hardcode French texts (`Démarrer le sondage` on the
  start screen): override the screens to translate.

## Examples

### A survey with a condition and persisted answers

```dart
import 'package:festenao_base_app/form/src/screen/form_screen_controller.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:flutter/material.dart';

/// Keeps the answers by question id (the base keeps them by index in
/// `answers`), and asks q2 only when q1 was answered 'yes'.
class MyFormPlayer extends TkFormPlayerBase {
  final savedAnswers = <String, TkFormPlayerQuestionAnswer?>{};

  MyFormPlayer()
    : super(
        id: 'feedback',
        form: TkFormPlayerFormBase(id: 'feedback', name: 'Feedback'),
        questions: [
          TkFormPlayerQuestion(
            id: 'q1',
            text: 'Did you attend?',
            options: TkFormPlayerQuestionChoiceOptions(
              choices: [
                TkFormPlayerQuestionChoice(id: 'yes', text: 'Yes'),
                TkFormPlayerQuestionChoice(id: 'no', text: 'No'),
              ],
            ),
          ),
          TkFormPlayerQuestion(
            id: 'q2',
            text: 'How many concerts?',
            options: TkFormPlayerQuestionIntOptions(min: 1, max: 20),
          ),
          TkFormPlayerQuestion(
            id: 'q3',
            text: 'Anything else?',
            options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
          ),
        ],
      );

  @override
  void setAnswer(int index, TkFormPlayerQuestionAnswer? answer) {
    super.setAnswer(index, answer);
    savedAnswers[getQuestion(index).id] = answer;
  }

  @override
  bool shouldSkip(int index) =>
      getQuestion(index).id == 'q2' && savedAnswers['q1']?.choiceId != 'yes';
}

Future<void> startFeedback(BuildContext context) => FormScreenControllerBase(
  player: MyFormPlayer(),
).goToFormStartScreen(context);
```

### Your own end screen

```dart
import 'package:festenao_base_app/form/src/screen/form_bloc.dart';
import 'package:festenao_base_app/form/src/screen/form_screen_controller.dart';
import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

class MyFormController extends FormScreenControllerBase {
  MyFormController({required super.player});

  @override
  Widget newEndScreen() => MyEndScreen(screenController: this);
}

class MyEndScreen extends StatelessWidget {
  final FormScreenController screenController;

  const MyEndScreen({super.key, required this.screenController});

  @override
  Widget build(BuildContext context) {
    // Provided by goToFormEndScreen.
    var bloc = BlocProvider.of<FormPlayerBloc>(context);
    return AppScaffold(
      appBar: AppBar(title: Text(bloc.player.form.name)),
      body: Center(
        child: ElevatedButton(
          // The questions are separate routes: leave them all.
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          child: const Text('Done'),
        ),
      ),
    );
  }
}
```

### Jumping to a question while developing

```dart
import 'package:festenao_base_app/form/src/screen/form_screen_controller.dart';
import 'package:festenao_base_app/form/src/screen/start_screen.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:flutter/foundation.dart';

void installDebugJump(TkFormPlayer player) {
  if (kDebugMode) {
    startScreenDebugOnInit = DebugOnInitState((context) async {
      await FormScreenControllerBase(
        player: player,
      ).goToQuestionScreen(context, questionIndex: 1);
    });
  }
}
```

## Common mistakes

* A question screen showing only a progress indicator:
  `QuestionPlayerScreenBloc` created without `player:` outside the survey
  flow.
* `Navigator.pop` from a custom end screen only goes back one question:
  pop until the route below the start screen instead.
* Reading `choiceId` on the answer of a `multi: true` choice question: the
  selection is in `choiceIds`.
