import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_navigator_flutter/content_navigator.dart';
import 'package:tekartik_common_utils/dev_utils.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/body_container.dart';
import 'package:tkcms_user_app/view/busy_screen_state_mixin.dart';
import 'package:tkcms_user_app/view/rx_busy_indicator.dart';

import 'form_bloc.dart';
import 'form_screen_controller.dart';
import 'thank_you_screen.dart';

class FormEndScreen extends StatefulWidget {
  final FormScreenController screenController;
  const FormEndScreen({super.key, required this.screenController});

  @override
  State<FormEndScreen> createState() => _FormEndScreenState();
}

class _FormEndScreenState extends State<FormEndScreen>
    with BusyScreenStateMixin<FormEndScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    busyDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FormPlayerBloc>(context);
    return AppScaffold(
      appBar: AppBar(),
      body: DelayedDisplay(
        child: Stack(
          children: [
            Center(
              child: ValueStreamBuilder(
                stream: bloc.state,
                builder: (context, snapshot) {
                  var player = snapshot.data?.player;
                  if (player == null) {
                    return const CircularProgressIndicator();
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      BodyContainer(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Text(
                                'Fin du formulaire, pour valider votre participation, cliquez sur le bouton ci-dessous.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 32),
                              Center(
                                child: ValueStreamBuilder(
                                  stream: busyStream,
                                  builder: (context, snapshot) {
                                    return ElevatedButton(
                                      onPressed:
                                          !(snapshot.data ?? false)
                                              ? () async {
                                                var result = await busyAction(
                                                  () async {
                                                    try {
                                                      /*
                                                    // ignore: unused_local_variable
                                                    var uid =
                                                        await gAppBloc
                                                            .localDatabase
                                                            .getUniqueDeviceId();
                                                    // ignore: unused_local_variable
                                                    var answers =
                                                        gAppBloc.surveyAnswers;
      */
                                                      return true;
                                                      /*
                                                    await gAppBloc.apiService
                                                        .addSurveyEntry(
                                                          FufFormApiAddSurveyEntryRequest()
                                                            ..app.v =
                                                                gAppBloc
                                                                    .appOptions
                                                                    .app
                                                            ..surveyId.v =
                                                                gAppBloc
                                                                    .surveyId
                                                            ..uid.v = uid
                                                            ..answers.v =
                                                                answers
                                                            ..timestamp.v =
                                                                gAppBloc
                                                                    .surveyStartTimestamp
                                                                    ?.toIso8601String(),
                                                        );
                                                    return true;*/
                                                    } catch (e, st) {
                                                      if (kDebugMode) {
                                                        print('Error: $e');
                                                        print(
                                                          'StackTrace: $st',
                                                        );
                                                      }
                                                      if (context.mounted) {
                                                        await muiSnack(
                                                          context,
                                                          'Une erreur est survenue, veuillez réessayer',
                                                        );
                                                      }
                                                      rethrow;
                                                    }
                                                  },
                                                );
                                                if (result.result ?? false) {
                                                  if (context.mounted) {
                                                    var stopAtNext = false;
                                                    await Navigator.pushAndRemoveUntil(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                        builder: (context) {
                                                          return const ThankYouScreen();
                                                        },
                                                      ),
                                                      (route) {
                                                        devPrint(
                                                          'Route: ${route.settings.name} ${stopAtNext ? 'stop' : ''}',
                                                        );
                                                        if (stopAtNext) {
                                                          return true;
                                                        }
                                                        if (FormStartContentPath()
                                                            .matchesString(
                                                              route
                                                                      .settings
                                                                      .name ??
                                                                  rootContentPathString,
                                                            )) {
                                                          stopAtNext = true;
                                                        } else if (FormEndContentPath()
                                                            .matchesString(
                                                              route
                                                                      .settings
                                                                      .name ??
                                                                  rootContentPathString,
                                                            )) {
                                                        } else if (FormQuestionContentPath()
                                                            .matchesString(
                                                              route
                                                                      .settings
                                                                      .name ??
                                                                  rootContentPathString,
                                                            )) {
                                                        } else {
                                                          return true;
                                                        }

                                                        return false;
                                                      },
                                                    );
                                                  }
                                                }
                                              }
                                              : null,
                                      child: const Text(
                                        'Valider',
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            BusyIndicator(busy: busyStream),
          ],
        ),
      ),
    );
  }
}
