import 'package:festenao_base_app/form/src/app/app_bloc.dart';
import 'package:festenao_base_app/form/src/screen/form_start_screen.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_sembast.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_test.dart';
import 'package:flutter/material.dart';

import 'package:tekartik_app_flutter_widget/mini_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:tekartik_firebase_firestore/utils/auto_id_generator.dart';

import 'question_screen.dart';
import 'thank_you_screen.dart';

class UserDebugScreen extends StatefulWidget {
  const UserDebugScreen({super.key});

  @override
  State<UserDebugScreen> createState() => _UserDebugScreenState();
}

var uid = AutoIdGenerator.autoId();

Future<void> initFormBloc({
  required DatabaseFactory databaseFactory,
  required AppFlavorContext appFlavorContext,
}) async {
  gAppBloc = AppBloc(
    databaseFactory: databaseFactory,
    appOptions: appFlavorContext,
    surveyId: 'test',
  );
  await gAppBloc.init();
  //globalSurveyPlayerFormBloc = SurveyPlayerFormBlocMemory(player: player);
  //await globalSurveyPlayerFormBloc.init();
}

TestFormPlayer oneQuestionFormEmptyAllowedPlayer() {
  return TestFormPlayer(
    id: 'test',
    questions: [
      TkFormPlayerQuestion(
        id: 'q1',
        text: 'My name is?',
        options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
      ),
    ],
    form: TkFormPlayerFormBase(id: 'f1', name: 'Form1'),
  );
}

class _UserDebugScreenState extends State<UserDebugScreen> {
  @override
  Widget build(BuildContext context) {
    return muiScreenWidget('Debug', () {
      muiItem('Thank you', () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ThankYouScreen()));
      });
      muiItem('One question form', () async {
        var player = TestFormPlayer(
          id: 'test',
          questions: [
            TkFormPlayerQuestion(
              id: 'q1',
              text: 'My name is?',
              options: TkFormPlayerQuestionTextOptions(),
            ),
          ],
          form: TkFormPlayerFormBase(id: 'f1', name: 'Form1'),
        );
        //globalSurveyPlayerFormBloc = SurveyPlayerFormBlocMemory(player: player);
        await goToQuestionScreen(context, questionIndex: 0, player: player);
      });
      muiItem('One question form empty allowed', () async {
        var player = oneQuestionFormEmptyAllowedPlayer();

        //globalSurveyPlayerFormBloc = SurveyPlayerFormBlocMemory(player: player);
        await goToQuestionScreen(context, questionIndex: 0, player: player);
      });
      muiItem('start form screen', () async {
        var player = oneQuestionFormEmptyAllowedPlayer();

        //globalSurveyPlayerFormBloc = SurveyPlayerFormBlocMemory(player: player);
        await goToFormStartScreen(context, player: player);
      });
      muiItem('Choice question form', () async {
        var player = TestFormPlayer(
          id: 'test',
          questions: [
            TkFormPlayerQuestion(
              id: 'q3',
              text: 'Choose notation',
              options: TkFormPlayerQuestionChoiceOptions(
                choices: [
                  TkFormPlayerQuestionChoice(id: 'c1', text: 'Choice 1'),
                  TkFormPlayerQuestionChoice(id: 'c2', text: 'Choice 2'),
                ],
              ),
            ),
          ],
          form: TkFormPlayerFormBase(id: 'f1', name: 'Form1'),
        );
        await goToQuestionScreen(context, questionIndex: 0, player: player);
      });
      muiItem('Multi question form', () async {
        var player = TestFormPlayer(
          id: 'test',
          questions: [
            TkFormPlayerQuestion(
              id: 'q1',
              text: 'My name is?',
              options: TkFormPlayerQuestionChoiceOptions(emptyAllowed: true),
            ),
            TkFormPlayerQuestion(
              id: 'q2',
              text: 'Your name is?',
              options: TkFormPlayerQuestionTextOptions(emptyAllowed: true),
            ),
            TkFormPlayerQuestion(
              id: 'q3',
              text: 'Choose notation',
              options: TkFormPlayerQuestionTextOptions(),
            ),
          ],
          form: TkFormPlayerFormBase(id: 'f1', name: 'Form1'),
        );
        //globalSurveyPlayerFormBloc = SurveyPlayerFormBlocMemory(player: player);
        await goToQuestionScreen(context, questionIndex: 0, player: player);
        if (muiBuildContext.mounted) {
          await muiSnack(muiBuildContext, 'Done');
        }
      });
    });
  }
}

Future<void> goToUserDebugScreen(BuildContext context) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const UserDebugScreen(),
    ),
  );
}
