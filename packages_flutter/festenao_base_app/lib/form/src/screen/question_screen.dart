import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:festenao_common/form/tk_form_db.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_common_utils/list_utils.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tkcms_user_app/theme/theme1.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/body_container.dart';
import 'package:tkcms_user_app/view/busy_screen_state_mixin.dart';
import 'package:tkcms_user_app/view/rx_busy_indicator.dart';

import 'end_screen.dart';
import 'form_question_screen_bloc.dart';
import 'form_screen_controller.dart';
import 'text_field_screen.dart';

var debugQuestionScreen = false; // devWarning(true);

// ignore: unused_element
void _log(String message) {
  if (debugQuestionScreen) {
    // ignore: avoid_print
    print('/fq $message');
  }
}

class QuestionScreen extends StatefulWidget {
  final FormScreenController screenController;

  const QuestionScreen({super.key, required this.screenController});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends AutoDisposeBaseState<QuestionScreen>
    with BusyScreenStateMixin<QuestionScreen> {
  final _noFocusNode = FocusNode();

  QuestionPlayerScreenBloc get bloc =>
      BlocProvider.of<QuestionPlayerScreenBloc>(context);

  /// Only valid during build
  int get questionIndex => bloc.questionIndex;
  final _smallScreen = BehaviorSubject.seeded(false);
  final canGoNextSubject = BehaviorSubject.seeded(false);
  final formKey = GlobalKey<FormState>();
  TextEditingController? textController;

  /// Not valid ruing initState
  TkFormPlayerQuestion? get playerQuestion =>
      bloc.state.valueOrNull?.playerState.question;

  var choicesSelected = <String>{};

  final _focus = FocusNode();

  void _onFocusChange() {
    _onFocusAndConstrainsChange();
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        var bloc = this.bloc;
        try {
          // var state = await bloc.state.first;
          // print('state: $state');
          var shouldSkip = bloc.player.shouldSkip(questionIndex);
          // print('shouldSkip: $shouldSkip');
          if (shouldSkip) {
            if (mounted) {
              Navigator.of(context).pop();
              _goToNext();
            }
          }
        } catch (e) {
          // print('state_error: $e');
          if (kDebugMode) {
            print('Error: $e');
          }
          await goToEndScreen(context);
        }
      }
    });
    super.initState();
    _focus.addListener(_onFocusChange);
    /*
    surveyInfo = gAppBloc.dbSurveyVS.valueOrNull?.details.v;
    question = surveyInfo?.questions.v?.list.v?.getOrNull(questionIndex);

    if (question == null) {
      sleep(0).then((_) {
        if (mounted) {
          if (question == null) {
            goToEndScreen(context);
          }
        }
      });
    } else {
      var question = this.question!;
      // Check conditions
      if (question.conditions.v?.list.v?.isNotEmpty ?? false) {
        try {
          var conditionMet = false;
          for (var condition in question.conditions.v!.list.v!) {
            //var tkAnswer = bloc.player.getAnswer(questionIndex);
            // print('tkAnswer: $tkAnswer');
            var answer = gAppBloc.getAnswer(condition.questionId.v!);
            if (condition.answerChoiceId.isNotNull) {
              if (answer?.choiceId.v == condition.answerChoiceId.v) {
                if (kDebugMode) {
                  print('Condition met: $condition');
                }
                conditionMet = true;
                break;
              } else if (answer?.choiceIds.v?.contains(
                    condition.answerChoiceId.v,
                  ) ??
                  false) {
                if (kDebugMode) {
                  print('Condition met: $condition');
                }
                conditionMet = true;
                break;
              }
            }
          }

          if (!conditionMet) {
            if (kDebugMode) {
              print('Conditions not met: ${question.conditions.v!.list.v}');
            }
            if (false)
              sleep(0).then((_) {
                if (mounted) {
                  Navigator.of(context).pop();
                  _goToNext();
                }
              });
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error checking conditions: $e');
          }
        }
      }
    }
*/
    _removeTextFocus();
    () async {
      await for (var _ in _smallScreen) {
        _onFocusAndConstrainsChange();
      }
    }();
  }

  void _removeTextFocus() {
    _focus.unfocus();
    _noFocusNode.requestFocus();
  }

  @override
  void dispose() {
    busyDispose();
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _noFocusNode.dispose();
    _smallScreen.close();
    canGoNextSubject.close();

    textController?.dispose();
    super.dispose();
  }

  bool validate() {
    _removeTextFocus();
    formKey.currentState?.save();
    if (formKey.currentState?.validate() ?? false) {
      var tkQuestion = bloc.state.value.playerState.question;
      var tkOptions = tkQuestion.options;

      var answer = _getEnteredAnswer();
      var answerRequired = !tkQuestion.options.emptyAllowed;

      bool okOrSnackIfRequired() {
        if (!answerRequired) {
          return true;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez saisir une réponse')),
        );
        return false;
      }

      if (tkOptions.isTypeInt) {
        if (answer?.answerInt.v == null) {
          return okOrSnackIfRequired();
        }
      } else if (tkOptions.isTypeText) {
        if (answer?.answerText.isNull ?? true) {
          return okOrSnackIfRequired();
        }
      } else if (tkOptions.isTypeChoiceMulti) {
        if (answer?.choiceIds.v?.isEmpty ?? true) {
          return okOrSnackIfRequired();
        }
      } else if (tkOptions.isTypeChoice) {
        if (answer?.choiceId.isNull ?? true) {
          return okOrSnackIfRequired();
        }
      }
      return true;
    }
    return false;
  }

  CvSurveyAnswer? _getEnteredAnswer() {
    var tkQuestion = bloc.state.value.playerState.question;
    var tkOptions = tkQuestion.options;
    var questionId = tkQuestion.id;
    if (tkOptions.isTypeInt) {
      var value = int.tryParse(textController!.text.trim());
      return CvSurveyAnswer()
        ..id.v = questionId
        ..answerInt.setValue(value);
    } else if (tkOptions.isTypeText) {
      var value = textController!.text.trimmedNonEmpty();
      return CvSurveyAnswer()
        ..id.v = questionId
        ..answerText.setValue(value);
    } else if (tkOptions.isTypeChoiceMulti) {
      return CvSurveyAnswer()
        ..id.v = questionId
        ..choiceIds.setValue(choicesSelected.toList().nonEmpty());
    } else if (tkOptions.isTypeChoice &&
        (tkOptions is TkFormPlayerQuestionChoiceOptions)) {
      var questionChoices = tkOptions.choices;
      var selectedChoiceId = choicesSelected.firstOrNull;
      if (selectedChoiceId != null) {
        var choice = questionChoices?.getChoiceById(selectedChoiceId);
        if (choice != null) {
          if (choice.allowOther) {
            var value = textController!.text.trimmedNonEmpty();
            return CvSurveyAnswer()
              ..id.v = questionId
              ..choiceId.v = selectedChoiceId
              ..answerText.setValue(value);
          }
        }
      }
      return CvSurveyAnswer()
        ..id.v = questionId
        ..choiceId.setValue(selectedChoiceId);

      /*
      // ignore: dead_code
      {
        // new choice
        var otherChoice = question.choices.v?.firstWhereOrNull(
          (choice) => choicesSelected.contains(choice.id.v!),
        );
        if (otherChoice?.otherAnswerType.v == surveyAnswerTypeText) {
          var value = textController!.text.trimmedNonEmpty();
          return CvSurveyAnswer()
            ..id.v = questionId
            ..choiceId.v = choicesSelected.first
            ..answerText.setValue(value);
        }
        return CvSurveyAnswer()
          ..id.v = question.id.v
          ..choiceId.setValue(choicesSelected.firstOrNull);
      }*/
    }
    return null;
  }

  TkFormPlayerQuestionAnswer? _getTkEnteredAnswer() {
    var tkQuestion = bloc.state.value.playerState.question;
    var tkOptions = tkQuestion.options;
    if (tkOptions.isTypeInt) {
      var value = int.tryParse(textController!.text.trim());
      return TkFormPlayerQuestionAnswer(intValue: value);
    } else if (tkOptions.isTypeText) {
      var value = textController!.text.trimmedNonEmpty();
      return TkFormPlayerQuestionAnswer(textValue: value);
    } else if (tkOptions.isTypeChoiceMulti) {
      return TkFormPlayerQuestionAnswer(choiceIds: choicesSelected.toList());
    } else if (tkOptions.isTypeChoice &&
        (tkOptions is TkFormPlayerQuestionChoiceOptions)) {
      var questionChoices = tkOptions.choices;
      var selectedChoiceId = choicesSelected.firstOrNull;
      if (selectedChoiceId != null) {
        var choice = questionChoices?.getChoiceById(selectedChoiceId);
        if (choice != null) {
          if (choice.allowOther) {
            var value = textController!.text.trimmedNonEmpty();
            return TkFormPlayerQuestionAnswer(
              choiceId: selectedChoiceId,
              textValue: value,
            );
          }
        }
      }
      return TkFormPlayerQuestionAnswer(choiceId: selectedChoiceId);

      /*
      // ignore: dead_code
      {
        // new choice
        var otherChoice = question.choices.v?.firstWhereOrNull(
          (choice) => choicesSelected.contains(choice.id.v!),
        );
        if (otherChoice?.otherAnswerType.v == surveyAnswerTypeText) {
          var value = textController!.text.trimmedNonEmpty();
          return CvSurveyAnswer()
            ..id.v = questionId
            ..choiceId.v = choicesSelected.first
            ..answerText.setValue(value);
        }
        return CvSurveyAnswer()
          ..id.v = question.id.v
          ..choiceId.setValue(choicesSelected.firstOrNull);
      }*/
    }
    return null;
  }

  void _goToNext() {
    widget.screenController.goToQuestionOrEndScreen(
      context,

      questionIndex: questionIndex + 1,
    );
  }

  bool validateAndGoNext() {
    if (validate()) {
      var tkAnswer = _getTkEnteredAnswer();
      if (tkAnswer != null) {
        bloc.questionPlayer.answer = tkAnswer;
      }
      _goToNext();
      return true;
    }
    return false;
  }

  final _dialogLock = Lock();

  void _onFocusAndConstrainsChange() {
    // print('show Dialog($_smallScreen.value, $_focus.hasFocus, $_lastFieldParam)');
    if (_smallScreen.value && _focus.hasFocus && _lastFieldParam != null) {
      //print('show Dialog()');
      if (!_dialogLock.locked) {
        _dialogLock.synchronized(() async {
          _removeTextFocus();
          await showTextFieldScreen(context, _lastFieldParam!);
          _removeTextFocus();
        });
      }
    }
  }

  bool _isSmallScreen(double height) {
    return height < 240;
  }

  var _formSetupDone = false;
  @override
  Widget build(BuildContext context) {
    var bloc = this.bloc;
    return StreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var tkBlocState = snapshot.data;
        var tkQuestion = tkBlocState?.playerState.question;
        // print('tkQuestion: $tkQuestion');
        return LayoutBuilder(
          builder: (context, constraints) {
            return AppScaffold(
              appBar: AppBar(),
              body: LayoutBuilder(
                builder: (context, constraints) {
                  //print('constraints: $constraints');
                  _smallScreen.add(_isSmallScreen(constraints.maxHeight));
                  if (tkQuestion == null) {
                    return Container();
                  }
                  if (!_formSetupDone) {
                    _formSetupDone = true;

                    var tkOptions = tkQuestion.options;
                    if (tkOptions.isTypeInt) {
                      textController = TextEditingController();
                    } else if (tkOptions.isTypeText) {
                      textController = TextEditingController();
                    } else if (tkOptions.isTypeChoice ||
                        tkOptions.isTypeChoiceMulti) {
                      textController = TextEditingController();
                    }
                    /*
                    if (tkQuestion.options.answerType.v == surveyAnswerTypeInt) {
                      textController = TextEditingController();
                    } else if (question.answerType.v == surveyAnswerTypeText) {
                      textController = TextEditingController();
                    } else if (question.answerType.v ==
                        surveyAnswerTypeChoice) {
                      // Check if other
                      if (question.choices.v?.firstWhereOrNull(
                            (choice) =>
                                choice.otherAnswerType.v ==
                                surveyAnswerTypeText,
                          ) !=
                          null) {
                        textController = TextEditingController();
                      }
                    }*/
                  }
                  return DelayedDisplay(
                    child: Stack(
                      children: [
                        Center(
                          child: Builder(
                            builder: (context) {
                              return Form(
                                key: formKey,
                                child: ListView(
                                  shrinkWrap: true,
                                  children: [
                                    BodyContainer(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: buildQuestion(
                                          context,
                                          tkBlocState!,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        BusyIndicator(busy: busyStream),
                      ],
                    ),
                  );
                },
              ),
              floatingActionButton: FloatingActionButton(
                child: const Icon(Icons.arrow_forward),
                onPressed: () {
                  validateAndGoNext();
                },
              ),
            );
          },
        );
      },
    );
  }

  Column buildQuestion(
    BuildContext context,
    QuestionPlayerScreenBlocState state,
  ) {
    var tkQuestion = state.playerState.question;
    var tkQuestionOptions = tkQuestion.options;
    var formPlayer = bloc.player;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            'Question ${questionIndex + 1} / ${formPlayer.questionCount}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 32),
        Text(tkQuestion.text, style: Theme.of(context).textTheme.titleMedium),

        if (tkQuestion.hint?.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          Text(
            tkQuestion.hint!,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        const SizedBox(height: 32),
        // Text('question: ${tkQuestion.toDebugString()} ${tkQuestionOptions} ${tkQuestionOptions.isTypeChoiceMulti}',),
        if (tkQuestionOptions.isTypeInt &&
            tkQuestionOptions is TkFormPlayerQuestionIntOptions) ...[
          if (tkQuestionOptions.presets?.isNotEmpty ?? false) ...[
            Center(
              child: Wrap(
                children: [
                  for (var preset in tkQuestionOptions.presets!)
                    Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: TextButton(
                        onPressed: () {
                          textController!.text = preset.toString();
                          validateAndGoNext();
                        },
                        child: Text(preset.toString()),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          textFormField(
            focusNode: _focus,
            controller: textController,
            onFieldSubmitted: (value) {
              validateAndGoNext();
            },
            //autofocus: true,
            decoration: const InputDecoration(
              //hintText: question.hint.v,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              var rawText = value?.trimmedNonEmpty();

              if (rawText == null) {
                if (tkQuestionOptions.emptyAllowed) {
                  return null;
                }
                return 'Veuillez saisir une valeur';
              }
              var intValue = int.tryParse(rawText);
              if (intValue == null) {
                return 'Veuillez saisir un nombre';
              }
              if (tkQuestionOptions.min != null &&
                  intValue < tkQuestionOptions.min!) {
                return 'Minimum ${tkQuestionOptions.min}';
              }
              if (tkQuestionOptions.max != null &&
                  intValue < tkQuestionOptions.max!) {
                return 'Maximum ${tkQuestionOptions.max}';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () {
                validateAndGoNext();
              },
              child: const Text('Valider'),
            ),
          ),
        ] else if (tkQuestionOptions.isTypeText &&
            tkQuestionOptions is TkFormPlayerQuestionTextOptions) ...[
          textFormField(
            focusNode: _focus,
            controller: textController,
            onFieldSubmitted: (value) {
              validateAndGoNext();
            },
            //autofocus: true,
            decoration: const InputDecoration(
              //hintText: question.hint.v,
            ),
            keyboardType: TextInputType.text,
            validator: (value) {
              var rawText = value?.trimmedNonEmpty();

              if (rawText == null) {
                if (tkQuestionOptions.emptyAllowed) {
                  return null;
                }
                return 'Veuillez saisir une réponse';
              }

              return null;
            },
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () {
                validateAndGoNext();
              },
              child: const Text('Valider'),
            ),
          ),
        ] else if (tkQuestionOptions.isTypeChoiceMulti &&
            tkQuestionOptions is TkFormPlayerQuestionChoiceOptions) ...[
          if (tkQuestionOptions.choices != null)
            ...tkQuestionOptions.choices!.map((choice) {
              return CheckboxListTile(
                title: Text(choice.text),
                value: choicesSelected.contains(choice.id),
                onChanged: (value) {
                  setState(() {
                    if (value ?? false) {
                      choicesSelected.add(choice.id);
                    } else {
                      choicesSelected.remove(choice.id);
                    }
                  });
                },
              );
            }),
        ] else if (tkQuestionOptions.isTypeChoice &&
            tkQuestionOptions is TkFormPlayerQuestionChoiceOptions) ...[
          Center(
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(width: 240),
                  if (tkQuestionOptions.choices != null)
                    ...tkQuestionOptions.choices!.map((choice) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                choicesSelected.contains(choice.id)
                                    ? colorBlueSelected
                                    : null,
                          ),
                          child: Text(choice.text),
                          onPressed: () {
                            setState(() {
                              choicesSelected
                                ..clear()
                                ..add(choice.id);
                            });
                            if (tkQuestionOptions
                                .choiceAllowOther) // was .otherAnswerType.v == surveyAnswerTypeText)
                            {
                            } else {
                              validateAndGoNext();
                            }
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          Builder(
            builder: (_) {
              var otherChoice = tkQuestionOptions.choices?.firstWhereOrNull(
                (choice) => choicesSelected.contains(choice.id),
              );
              if (otherChoice?.allowOther ?? false) {
                return Column(
                  children: [
                    const SizedBox(height: 32),
                    textFormField(
                      focusNode: _focus,
                      controller: textController,
                      onFieldSubmitted: (value) {
                        validateAndGoNext();
                      },
                      decoration: InputDecoration(
                        hintText: otherChoice?.text,
                        //hintText: question.hint.v,
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        var rawText = value?.trimmedNonEmpty();

                        if (rawText == null) {
                          if (tkQuestionOptions.emptyAllowed) {
                            return null;
                          }
                          return 'Veuillez saisir une réponse';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          validateAndGoNext();
                        },
                        child: const Text('Valider'),
                      ),
                    ),
                  ],
                );
              }
              return Container();
            },
          ),
        ],
        const SizedBox(height: 64),
      ],
    );
  }

  TextFieldParam? _lastFieldParam;

  Widget textFormField({
    required FocusNode focusNode,
    TextEditingController? controller,
    ValueChanged<String>? onFieldSubmitted,
    InputDecoration? decoration,
    TextInputType? keyboardType,
    FormFieldValidator<String?>? validator,
  }) {
    _lastFieldParam = TextFieldParam(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
    );
    return ValueStreamBuilder(
      stream: _smallScreen,
      builder: (context, snapshot) {
        return TextFormField(
          focusNode: focusNode,
          controller: controller,
          onFieldSubmitted: onFieldSubmitted,
          //autofocus: true,
          decoration: decoration,
          keyboardType:
              !(snapshot.data ?? false) ? keyboardType : TextInputType.none,
          validator: validator,
        );
      },
    );
  }
}
