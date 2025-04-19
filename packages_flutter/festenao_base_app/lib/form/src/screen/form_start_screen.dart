import 'package:festenao_base_app/form/src/view/app_scaffold.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/form/tk_form.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tekartik_app_flutter_widget/delayed_display.dart';
import 'package:tekartik_common_utils/num_utils.dart';
import 'package:tkcms_user_app/tkcms_audi.dart';
import 'package:tkcms_user_app/view/body_container.dart';

import 'debug_screen.dart';
import 'form_bloc.dart';
import 'question_screen.dart';

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

class FormStartScreen extends StatefulWidget {
  const FormStartScreen({super.key});

  @override
  State<FormStartScreen> createState() => _FormStartScreenState();
}

class _FormStartScreenState extends State<FormStartScreen> {
  @override
  void initState() {
    startScreenDebugOnInit?.init(this);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var bloc = BlocProvider.of<FormPlayerBloc>(context);
    return ValueStreamBuilder(
      stream: bloc.state,
      builder: (context, snapshot) {
        var player = snapshot.data?.player;
        return AppScaffold(
          appBar: AppBar(),
          body: LayoutBuilder(
            builder: (context, constraints) {
              var imgWidth = (constraints.maxWidth * 0.6)
                  .boundedMax(constraints.maxHeight * .6)
                  .bounded(128, 512);
              return DelayedDisplay(
                child: Center(
                  child: Builder(
                    builder: (context) {
                      if (player == null) {
                        return const CircularProgressIndicator();
                      }
                      var form = player.form;

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
                                    form.name,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 32),
                                  Center(
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if (context.mounted) {
                                          await goToQuestionOrEndScreen(
                                            context,
                                            player: player,
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
          floatingActionButton:
              kDebugMode
                  ? FloatingActionButton(
                    onPressed: () {
                      goToUserDebugScreen(context);
                    },
                    child: const Icon(Icons.settings),
                  )
                  : null,
        );
      },
    );
  }
}

Future<void> goToFormStartScreen(
  BuildContext context, {
  required TkFormPlayer player,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) {
        return BlocProvider(
          blocBuilder: () => FormPlayerBloc(player: player),
          child: const FormStartScreen(),
        );
      },
    ),
  );
}
