import 'dart:async';

import 'package:festenao_common/test/quizz_test_fixtures.dart';
import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:festenao_dashboard_base_app/src/provider/quizz_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The quizz home of a project: its questions (add, edit, delete) and its
/// quizzes (create, control).
///
/// Takes no argument: the project id comes from [currentProjectIdProvider],
/// which the route tree scopes from the location.
class QuizzHomeScreen extends ConsumerStatefulWidget {
  /// The route name.
  static const routeName = 'quizz';

  /// Creates the screen.
  const QuizzHomeScreen({super.key});

  @override
  ConsumerState<QuizzHomeScreen> createState() => _QuizzHomeScreenState();
}

class _QuizzHomeScreenState extends ConsumerState<QuizzHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get projectId => ref.read<String>(currentProjectIdProvider);

  @override
  Widget build(BuildContext context) {
    var projectId = ref.watch(currentProjectIdProvider);
    return Scaffold(
      appBar: AppBar(
        leading: RouteUpBackButton(upPath: dashboardProjectPath),
        title: Text('Quizz – $projectId'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.help_outline), text: 'Questions'),
            Tab(icon: Icon(Icons.quiz), text: 'Quizzes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _QuestionsTab(projectId: projectId),
          _QuizzesTab(projectId: projectId),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_tabs.index == 0) {
            context.pushPath(
              quizzQuestionCreatePath,
              parameters: {DashboardRouteParams.projectId: projectId},
            );
          } else {
            unawaited(_createQuiz(context, projectId));
          }
        },
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Question' : 'Quiz'),
      ),
    );
  }

  Future<void> _createQuiz(BuildContext context, String projectId) async {
    var db = ref.read(quizzDatabaseProvider(projectId));
    var timeService = ref.read(quizzTimeServiceProvider);
    var config = await showDialog<FsQuizConfig>(
      context: context,
      builder: (context) => _QuizConfigDialog(
        initialConfig: FsQuizConfig()
          ..questionCount.v = quizConfigQuestionCountDefault
          ..preDelayMs.v = quizConfigPreDelayMsDefault
          ..answerDelayMs.v = quizConfigAnswerDelayMsDefault
          ..pauseDelayMs.v = quizConfigPauseDelayMsDefault
          ..validationDelayMs.v = quizConfigValidationDelayMsDefault,
      ),
    );
    if (config == null) {
      return;
    }
    try {
      var now = timeService.timestamp;
      var quiz = await db.createTvQuiz(now: now, config: config);
      await db.makeQuizPreActive(
        quizId: quiz.id,
        now: now,
        controllerId: ref.read(quizzDeviceIdProvider),
      );
      if (context.mounted) {
        unawaited(
          context.pushPath(
            quizzControlPath,
            parameters: {
              DashboardRouteParams.projectId: projectId,
              DashboardRouteParams.quizId: quiz.id,
            },
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _QuestionsTab extends ConsumerWidget {
  final String projectId;
  const _QuestionsTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var questions = ref.watch(quizzQuestionsProvider(projectId));
    return questions.when(
      data: (questions) {
        if (questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No question yet'),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () async {
                    var db = ref.read(quizzDatabaseProvider(projectId));
                    await db.addQuestion(newQuizzTestQuestion1());
                    await db.addQuestion(newQuizzTestQuestion2());
                  },
                  child: const Text('Add 2 sample questions'),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: questions.length,
          itemBuilder: (context, index) {
            var question = questions[index];
            var text = question.text.v;
            var tags = question.tags.v ?? <String>[];
            return ListTile(
              leading: Icon(
                question.disabled.v == true
                    ? Icons.visibility_off
                    : Icons.help_outline,
              ),
              title: Text(text?.defaultText ?? '(no text)'),
              subtitle: Text(
                [
                  '${question.answerCount} answers',
                  if (tags.isNotEmpty) tags.join(', '),
                  if (question.disabled.v == true) 'disabled',
                ].join(' · '),
              ),
              onTap: () {
                context.pushPath(
                  quizzQuestionEditPath,
                  parameters: {
                    DashboardRouteParams.projectId: projectId,
                    DashboardRouteParams.questionId: question.id,
                  },
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _QuizzesTab extends ConsumerWidget {
  final String projectId;
  const _QuizzesTab({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var quizzes = ref.watch(quizzQuizzesProvider(projectId));
    return quizzes.when(
      data: (quizzes) {
        if (quizzes.isEmpty) {
          return const Center(child: Text('No quiz yet'));
        }
        return ListView.builder(
          itemCount: quizzes.length,
          itemBuilder: (context, index) {
            var quiz = quizzes[index];
            var created = quiz.createdTimestamp.v?.toDateTime();
            var status = ref.watch(
              quizzQuizStatusProvider((projectId: projectId, quizId: quiz.id)),
            );
            return ListTile(
              leading: const Icon(Icons.quiz),
              title: Text('Quiz ${quiz.id}'),
              subtitle: Text(
                [
                  '${quiz.questions.v?.length ?? 0} questions',
                  if (created != null) quizzFormatDateTime(created),
                  status.value?.status.v ?? '',
                ].join(' · '),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  var db = ref.read(quizzDatabaseProvider(projectId));
                  await db.deleteQuiz(quiz.id);
                },
              ),
              onTap: () {
                context.pushPath(
                  quizzControlPath,
                  parameters: {
                    DashboardRouteParams.projectId: projectId,
                    DashboardRouteParams.quizId: quiz.id,
                  },
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }
}

class _QuizConfigDialog extends StatefulWidget {
  final FsQuizConfig initialConfig;
  const _QuizConfigDialog({required this.initialConfig});

  @override
  State<_QuizConfigDialog> createState() => _QuizConfigDialogState();
}

class _QuizConfigDialogState extends State<_QuizConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _questionCount = TextEditingController(
    text: '${widget.initialConfig.questionCountOrDefault}',
  );
  late final _preDelay = TextEditingController(
    text: '${widget.initialConfig.preDelayMsOrDefault ~/ 1000}',
  );
  late final _answerDelay = TextEditingController(
    text: '${widget.initialConfig.answerDelayMsOrDefault ~/ 1000}',
  );
  late final _pauseDelay = TextEditingController(
    text: '${widget.initialConfig.pauseDelayMsOrDefault ~/ 1000}',
  );
  late final _validationDelay = TextEditingController(
    text: '${widget.initialConfig.validationDelayMsOrDefault ~/ 1000}',
  );

  @override
  void dispose() {
    _questionCount.dispose();
    _preDelay.dispose();
    _answerDelay.dispose();
    _pauseDelay.dispose();
    _validationDelay.dispose();
    super.dispose();
  }

  String? _validateInt(String? value) {
    if (int.tryParse(value?.trim() ?? '') == null) {
      return 'Enter a number';
    }
    return null;
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
      validator: _validateInt,
    ),
  );

  int _seconds(TextEditingController controller) =>
      int.parse(controller.text.trim()) * 1000;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New quiz'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_questionCount, 'Question count'),
              _field(_preDelay, 'Delay before the first question (s)'),
              _field(_answerDelay, 'Time to answer a question (s)'),
              _field(_pauseDelay, 'Pause between questions (s)'),
              _field(_validationDelay, 'Players validation delay (s)'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              FsQuizConfig()
                ..questionCount.v = int.parse(_questionCount.text.trim())
                ..preDelayMs.v = _seconds(_preDelay)
                ..answerDelayMs.v = _seconds(_answerDelay)
                ..pauseDelayMs.v = _seconds(_pauseDelay)
                ..validationDelayMs.v = _seconds(_validationDelay),
            );
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
