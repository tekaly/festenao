import 'package:festenao_base_app/form/src/app/app_bloc.dart';
import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_common_utils/num_utils.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import 'debug_screen.dart';
import 'form_screen.dart';
import 'form_screen_controller.dart';

class DebugOnInitState {
  var _done = false;
  final DebugOnInitBuildContextCallback callback;

  DebugOnInitState(this.callback);
  FutureOr<void> init(State state) {
    if (!_done) {
      _done = true;
      // ignore: avoid_print
      print('## Debugging quick action');
      return sleep(0).then((_) {
        if (state.mounted) {
          return callback(state.context);
        }
      });
    }
  }
}

typedef DebugOnInitBuildContextCallback =
    FutureOr<void> Function(BuildContext context);

DebugOnInitState? startScreenDebugOnInit;

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    startScreenDebugOnInit?.init(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          var imgWidth = (constraints.maxWidth * 0.6)
              .boundedMax(constraints.maxHeight * .6)
              .bounded(128, 512);
          return DelayedDisplay(
            child: Center(
              child: gAppBloc.surveyIdOrNull == null
                  ? ListView(
                      shrinkWrap: true,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              SizedBox(
                                width: imgWidth,
                                height: imgWidth,
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: imgWidth,
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Veuillez scanner le QR code pour commencer',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 64),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ValueStreamBuilder(
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
                                    SizedBox(
                                      width: imgWidth,
                                      height: imgWidth,
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        size: imgWidth,
                                      ),
                                    ),
                                    Text(
                                      'Bienvenue sur le sondage mobilité WTF\u{00A0}#6',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 32),
                                    Center(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          gAppBloc.startSurvey();
                                          var player =
                                              globalSurveyPlayerFormBloc
                                                  .newPlayer();

                                          /// Wait for survey to be loaded
                                          await globalSurveyPlayerFormBloc
                                              .state
                                              .first;
                                          if (context.mounted) {
                                            var screenController =
                                                FormScreenControllerBase(
                                                  player: player,
                                                );
                                            await screenController
                                                .goToQuestionOrEndScreen(
                                                  context,

                                                  questionIndex: 0,
                                                  //
                                                );
                                          }
                                        },
                                        child: const Text(
                                          'Démarrer le sondage',
                                          textAlign: TextAlign.center,
                                        ),
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
          );
        },
      ),
      floatingActionButton: kDebugMode
          ? FloatingActionButton(
              onPressed: () {
                goToUserDebugScreen(context);
              },
              child: const Icon(Icons.settings),
            )
          : null,
    );
  }
}
