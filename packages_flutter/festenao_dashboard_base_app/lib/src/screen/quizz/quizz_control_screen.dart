import 'package:barcode_widget/barcode_widget.dart';
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:festenao_dashboard_base_app/src/provider/quizz_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The admin control of a quiz: start it, pause/resume/navigate, show the
/// player link (qr code), validate the players at the end and see the
/// ranking. The tv display is one tap away.
class QuizzControlScreen extends ConsumerStatefulWidget {
  /// The quiz id.
  final String quizId;

  /// Creates the screen.
  const QuizzControlScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizzControlScreen> createState() => _QuizzControlScreenState();
}

class _QuizzControlScreenState extends ConsumerState<QuizzControlScreen> {
  String get quizId => widget.quizId;
  String get projectId => ref.read<String>(currentProjectIdProvider);

  var _showValidation = false;
  var _computeStarted = false;

  ({String projectId, String quizId}) get _key =>
      (projectId: projectId, quizId: quizId);

  void _onStateNow(QuizPlayerStateNow stateNow) {
    // Once in post, wait for the results, show the validation, then compute
    // the ranks (once).
    if (stateNow.isValidNotCancelled && stateNow.isPost && !_computeStarted) {
      _computeStarted = true;
      var controller = ref.read(quizzAdminControllerProvider(_key));
      controller.waitAndComputePlayerRanks(stateNow.now).listen((event) {
        if (!mounted) {
          return;
        }
        if (event.waitingForValidationDone == true) {
          setState(() {
            _showValidation = false;
          });
        } else if (event.waitingForNewPlayersDone == true) {
          setState(() {
            _showValidation = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var projectId = ref.watch(currentProjectIdProvider);
    var controller = ref.watch(quizzAdminControllerProvider(_key));
    var database = ref.watch(quizzDatabaseProvider(projectId));
    var timeService = ref.watch(quizzTimeServiceProvider);
    var playUri = ref.watch(quizzUserPlayUriBuilderProvider)(
      projectId: projectId,
      quizId: quizId,
    );
    return Scaffold(
      appBar: AppBar(
        leading: RouteUpBackButton(upPath: quizzHomePath),
        title: Text('Quiz $quizId'),
        actions: [
          IconButton(
            tooltip: 'TV display',
            icon: const Icon(Icons.tv),
            onPressed: () {
              context.pushPath(
                quizzTvPath,
                parameters: {
                  DashboardRouteParams.projectId: projectId,
                  DashboardRouteParams.quizId: quizId,
                },
              );
            },
          ),
        ],
      ),
      body: QuizzStateNowBuilder(
        controller: controller,
        builder: (context, stateNow) {
          if (stateNow == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!stateNow.quizExists) {
            return const Center(child: Text('Quiz not found'));
          }
          _onStateNow(stateNow);
          var quiz = stateNow.cache.quiz;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Column(
                      children: [
                        QuizzStatusWidget(
                          stateNow: stateNow,
                          auto: false,
                          controller: controller,
                        ),
                        if (stateNow.isIdle ||
                            (stateNow.isPre && stateNow.isPaused))
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: () {
                                    var endPreMs =
                                        controller.stateValue.cache.preMsEnd;
                                    controller.startActiveQuiz(
                                      timeService.timestamp.add(
                                        Duration(milliseconds: 3000 - endPreMs),
                                      ),
                                    );
                                  },
                                  child: const Text('Start in 3 s'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    var endPreMs =
                                        controller.stateValue.cache.preMsEnd;
                                    controller.startActiveQuiz(
                                      timeService.timestamp.add(
                                        Duration(
                                          milliseconds: 10000 - endPreMs,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Start in 10 s'),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    controller.startActiveQuiz(
                                      timeService.timestamp,
                                    );
                                  },
                                  child: Text(
                                    'Start in ${quiz.preDelayMsOrDefault ~/ 1000} s',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (stateNow.isPlayingOrPaused)
                          QuizzControlWidget(controller: controller),
                        if (!stateNow.isDoneOrArchived && !stateNow.isCancelled)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await controller.cancelQuiz();
                                },
                                icon: const Icon(Icons.cancel_outlined),
                                label: const Text('Cancel the quiz'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (stateNow.isValidNotCancelled && !stateNow.isPost) ...[
                    const SizedBox(height: 16),
                    Card(
                      child: Column(
                        children: [
                          const ListTile(
                            title: Text('Player link'),
                            subtitle: Text('Scan to join the quiz'),
                          ),
                          InkWell(
                            onTap: () {
                              var data = playUri.toString();
                              Clipboard.setData(ClipboardData(text: data));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$data copied to clipboard'),
                                ),
                              );
                            },
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(16),
                              child: BarcodeWidget(
                                barcode: Barcode.qrCode(
                                  errorCorrectLevel:
                                      BarcodeQRCorrectionLevel.high,
                                ),
                                data: playUri.toString(),
                                width: 200,
                                height: 200,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: SelectableText(
                              playUri.toString(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_showValidation && !stateNow.isDoneOrArchived) ...[
                    const SizedBox(height: 16),
                    QuizzValidationWidget(
                      database: database,
                      timeService: timeService,
                      quiz: quiz,
                      advancedMode: true,
                      onEnd: () {
                        if (mounted) {
                          setState(() {
                            _showValidation = false;
                          });
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Card(
                    child: Column(
                      children: [
                        const ListTile(title: Text('Players')),
                        QuizzTopPlayersWidget(
                          database: database,
                          quizId: quizId,
                          showNames: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Details'),
                    children: [
                      ListTile(
                        title: const Text('Status'),
                        subtitle: Text(stateNow.status.status.v ?? ''),
                      ),
                      ListTile(
                        title: const Text('Questions'),
                        subtitle: Text('${quiz.questions.v?.length ?? 0}'),
                      ),
                      ListTile(
                        title: const Text('Session'),
                        subtitle: Text(quiz.sessionId.v ?? ''),
                      ),
                      if (quiz.createdTimestamp.v != null)
                        ListTile(
                          title: const Text('Created'),
                          subtitle: Text(
                            quizzFormatDateTime(
                              quiz.createdTimestamp.v!.toDateTime(),
                            ),
                          ),
                        ),
                      if (controller.apiClientOrNull != null)
                        ListTile(
                          title: const Text('Send a fake player (test)'),
                          onTap: () {
                            controller.sendRandomPlayer();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
