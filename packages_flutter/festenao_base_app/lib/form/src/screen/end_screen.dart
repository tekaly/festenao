import 'package:festenao_base_app/form/src/app/app_bloc.dart';
import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_app_flutter_widget/mini_ui.dart';
import 'package:tekartik_app_navigator_flutter/page_route.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/body_container.dart';
import 'package:tkcms_user_app/view/busy_screen_state_mixin.dart';
import 'package:tkcms_user_app/view/rx_busy_indicator.dart';

import 'thank_you_screen.dart';

class EndScreen extends StatefulWidget {
  const EndScreen({super.key});

  @override
  State<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends State<EndScreen>
    with BusyScreenStateMixin<EndScreen> {
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
    return AppScaffold(
      appBar: AppBar(),
      body: DelayedDisplay(
        child: Stack(
          children: [
            Center(
              child: ValueStreamBuilder(
                stream: gAppBloc.dbSurveyVS,
                builder: (context, snapshot) {
                  var survey = snapshot.data;
                  if (survey == null) {
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
                                'Fin du sondage, pour valider votre participation, cliquez sur le bouton ci-dessous.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 32),
                              Center(
                                child: ValueStreamBuilder(
                                  stream: busyStream,
                                  builder: (context, snapshot) {
                                    return ElevatedButton(
                                      onPressed: !(snapshot.data ?? false)
                                          ? () async {
                                              var result = await busyAction(() async {
                                                try {
                                                  // ignore: unused_local_variable
                                                  var uid = await gAppBloc
                                                      .localDatabase
                                                      .getUniqueDeviceId();
                                                  // ignore: unused_local_variable
                                                  var answers =
                                                      gAppBloc.surveyAnswers;

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
                                                } catch (e) {
                                                  if (context.mounted) {
                                                    await muiSnack(
                                                      context,
                                                      'Une erreur est survenue, veuillez réessayer',
                                                    );
                                                  }
                                                  rethrow;
                                                }
                                              });
                                              if (result.result ?? false) {
                                                if (context.mounted) {
                                                  await Navigator.pushAndRemoveUntil(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                      builder: (context) {
                                                        return const ThankYouScreen();
                                                      },
                                                    ),
                                                    (route) {
                                                      if (route.settings.name ==
                                                          '/') {
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

Future<void> goToEndScreen(BuildContext context) async {
  await Navigator.of(context).push(
    NoAnimationMaterialPageRoute<void>(
      builder: (context) {
        return const EndScreen();
      },
    ),
  );
}
