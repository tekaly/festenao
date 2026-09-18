import 'package:barcode_widget/barcode_widget.dart';
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:festenao_dashboard_base_app/src/provider/quizz_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The tv display of a quiz: the player link while waiting, each question
/// with its countdown, the correct answer during the pause, the podium at
/// the end. The ranks are computed automatically once the quiz is over.
class QuizzTvScreen extends ConsumerStatefulWidget {
  /// The quiz id.
  final String quizId;

  /// Creates the screen.
  const QuizzTvScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizzTvScreen> createState() => _QuizzTvScreenState();
}

class _QuizzTvScreenState extends ConsumerState<QuizzTvScreen> {
  String get quizId => widget.quizId;
  String get projectId => ref.read<String>(currentProjectIdProvider);
  var _computeStarted = false;

  ({String projectId, String quizId}) get _key =>
      (projectId: projectId, quizId: quizId);

  void _onStateNow(QuizPlayerStateNow stateNow) {
    if (stateNow.isValidNotCancelled && stateNow.isPost && !_computeStarted) {
      _computeStarted = true;
      ref
          .read(quizzAdminControllerProvider(_key))
          .waitAndComputePlayerRanks(stateNow.now, auto: true);
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
    const background = Color(0xff3949f5);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            QuizzStateNowBuilder(
              controller: controller,
              builder: (context, stateNow) {
                if (stateNow == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                _onStateNow(stateNow);
                return LayoutBuilder(
                  builder: (context, constraints) {
                    var width = constraints.maxWidth;
                    var titleStyle = TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: width * .05,
                    );
                    if (!stateNow.isValid) {
                      return Center(
                        child: Text('Quiz not started', style: titleStyle),
                      );
                    }
                    if (stateNow.isCancelled) {
                      return Center(
                        child: Text('Quiz cancelled', style: titleStyle),
                      );
                    }
                    if (stateNow.isIdle || stateNow.isPre) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Welcome to the quiz', style: titleStyle),
                          SizedBox(height: width * .02),
                          Text(
                            'Scan to play',
                            style: titleStyle.copyWith(fontSize: width * .03),
                          ),
                          SizedBox(height: width * .02),
                          Container(
                            color: Colors.white,
                            padding: EdgeInsets.all(width * .01),
                            child: BarcodeWidget(
                              width: width * .25,
                              height: width * .25,
                              barcode: Barcode.qrCode(
                                errorCorrectLevel:
                                    BarcodeQRCorrectionLevel.high,
                              ),
                              data: playUri.toString(),
                            ),
                          ),
                          SizedBox(height: width * .02),
                          if (stateNow.isPre)
                            QuizzProgressTimeWidget(
                              controller: stateNow.preProgressController,
                              timeService: timeService,
                              width: width * .15,
                              fontSize: width * .03,
                              shadowColor: Colors.red,
                            ),
                        ],
                      );
                    }
                    if (stateNow.isPost) {
                      return Padding(
                        padding: EdgeInsets.all(width * .05),
                        child: Column(
                          children: [
                            Text('Results', style: titleStyle),
                            Expanded(
                              child: QuizzResultPodiumWidget(
                                database: database,
                                quizId: quizId,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    var questionIndex = stateNow.questionIndex;
                    if (questionIndex == null) {
                      return const SizedBox.shrink();
                    }
                    var question = stateNow.getQuestionAt(questionIndex);
                    var remainingMs = stateNow.getQuestionAnswerRemainingMs(
                      questionIndex,
                    );
                    var answering = remainingMs > 0;
                    return Padding(
                      padding: EdgeInsets.all(width * .04),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${questionIndex + 1} / ${stateNow.questionCount}',
                                style: titleStyle.copyWith(
                                  fontSize: width * .03,
                                ),
                              ),
                              if (answering)
                                QuizzProgressTimeWidget(
                                  controller: stateNow
                                      .getQuestionProgressController(
                                        questionIndex,
                                      ),
                                  timeService: timeService,
                                  width: width * .12,
                                  fontSize: width * .03,
                                  shadowColor: Colors.red,
                                ),
                            ],
                          ),
                          SizedBox(height: width * .02),
                          QuizzStepProgressIndicator(
                            controller: answering
                                ? stateNow.getQuestionProgressController(
                                    questionIndex,
                                  )
                                : stateNow.getQuestionPostProgressController(
                                    questionIndex,
                                  ),
                            timeService: timeService,
                          ),
                          SizedBox(height: width * .02),
                          Expanded(
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Text(
                                      question.text.v?.frText ?? '',
                                      style: titleStyle.copyWith(
                                        fontSize: width * .035,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (question.text.v?.enText != null &&
                                        question.text.v?.enText !=
                                            question.text.v?.frText) ...[
                                      SizedBox(height: width * .01),
                                      Text(
                                        question.text.v?.enText ?? '',
                                        style: titleStyle.copyWith(
                                          fontSize: width * .025,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                    SizedBox(height: width * .02),
                                    for (var answer
                                        in question.answers.v ?? <CvAnswer>[])
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: width * .005,
                                        ),
                                        child: QuizzRoundedText(
                                          '${answer.id.v}. ${answer.text.v?.frText ?? answer.text.v?.defaultText ?? ''}',
                                          width: width * .7,
                                          fontSize: width * .022,
                                          fontWeight: FontWeight.w700,
                                          textColor:
                                              !answering &&
                                                  answer.id.v ==
                                                      question.correctAnswerId.v
                                              ? Colors.white
                                              : Colors.black,
                                          decoration:
                                              !answering &&
                                                  answer.id.v ==
                                                      question.correctAnswerId.v
                                              ? BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        width * .022,
                                                      ),
                                                  color: Colors.green,
                                                )
                                              : null,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                color: Colors.white54,
                tooltip: 'Back to the control screen',
                icon: const Icon(Icons.close),
                onPressed: () {
                  context.popOrGoPath(quizzControlPath);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
