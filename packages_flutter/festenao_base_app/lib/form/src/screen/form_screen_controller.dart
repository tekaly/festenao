import 'package:festenao_base_app/form/src/screen/question_screen.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tekartik_app_navigator_flutter/page_route.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';

import 'form_bloc.dart';
import 'form_end_screen.dart';
import 'form_question_screen_bloc.dart';
import 'form_start_screen.dart';

abstract class FormScreenController {
  final TkFormPlayer player;

  FormScreenController({required this.player});

  Future<void> goToQuestionScreen(
    BuildContext context, {
    required int questionIndex,
  });
  Widget newQuestionScreen();
  Future<void> goToFormEndScreen(BuildContext context);
  Widget newEndScreen();

  Future<void> goToQuestionOrEndScreen(
    BuildContext context, {

    required int questionIndex,
  });
  Widget newStartScreen();
}

class FormQuestionContentPath extends ContentPathBase {
  final question = ContentPathField('question');
  @override
  List<ContentPathField> get fields => [question];
}

class FormStartContentPath extends ContentPathBase {
  final _part = ContentPathPart('start');
  @override
  List<ContentPathField> get fields => [_part];
}

class FormEndContentPath extends ContentPathBase {
  final _part = ContentPathPart('end');
  @override
  List<ContentPathField> get fields => [_part];
}

class FormScreenControllerBase implements FormScreenController {
  @override
  final TkFormPlayer player;

  FormScreenControllerBase({required this.player});

  @override
  Widget newQuestionScreen() {
    return QuestionScreen(screenController: this);
  }

  @override
  Future<void> goToQuestionScreen(
    BuildContext context, {
    required int questionIndex,
  }) async {
    await Navigator.of(context).push(
      NoAnimationMaterialPageRoute<void>(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => QuestionPlayerScreenBloc(
              questionIndex: questionIndex,
              player: player,
            ),
            child: newQuestionScreen(),
          );
        },
        settings: (FormQuestionContentPath()..question.value = '$questionIndex')
            .routeSettings()
            .toRaw(),
      ),
    );
  }

  @override
  Widget newEndScreen() {
    return FormEndScreen(screenController: this);
  }

  @override
  Future<void> goToFormEndScreen(BuildContext context) async {
    await Navigator.of(context).push(
      NoAnimationMaterialPageRoute<void>(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => FormPlayerBloc(player: player),
            child: newEndScreen(),
          );
        },
        settings: FormEndContentPath().routeSettings().toRaw(),
      ),
    );
  }

  @override
  Future<void> goToQuestionOrEndScreen(
    BuildContext context, {

    required int questionIndex,
  }) async {
    var count = player.questionCount;
    if (questionIndex >= count) {
      await goToFormEndScreen(context);
    } else {
      await goToQuestionScreen(context, questionIndex: questionIndex);
    }
  }

  @override
  Widget newStartScreen() {
    return FormStartScreen(screenController: this);
  }

  Future<void> goToFormStartScreen(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          return BlocProvider(
            blocBuilder: () => FormPlayerBloc(player: player),
            child: newStartScreen(),
          );
        },
        settings: FormStartContentPath().routeSettings().toRaw(),
      ),
    );
  }
}
