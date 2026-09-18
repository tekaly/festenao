import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:festenao_dashboard_base_app/src/provider/quizz_providers.dart';
import 'package:festenao_dashboard_base_app/src/provider/route_scope_providers.dart';
import 'package:festenao_dashboard_base_app/src/router/dashboard_route_paths.dart';
import 'package:festenao_navigator_flutter/festenao_navigator_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Creates ([questionId] null) or edits a question: its text (en, fr), its
/// answers with the correct one, its tags and its disabled flag.
class QuizzQuestionEditScreen extends ConsumerStatefulWidget {
  /// The question id, null to create one.
  final String? questionId;

  /// Creates the screen.
  const QuizzQuestionEditScreen({super.key, required this.questionId});

  @override
  ConsumerState<QuizzQuestionEditScreen> createState() =>
      _QuizzQuestionEditScreenState();
}

class _AnswerControllers {
  final String id;
  final en = TextEditingController();
  final fr = TextEditingController();
  _AnswerControllers(this.id, CvAnswer? answer) {
    en.text = answer?.text.v?.en.v ?? '';
    fr.text = answer?.text.v?.fr.v ?? '';
  }
  void dispose() {
    en.dispose();
    fr.dispose();
  }
}

class _QuizzQuestionEditScreenState
    extends ConsumerState<QuizzQuestionEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textEn = TextEditingController();
  final _textFr = TextEditingController();
  final _tags = TextEditingController();
  final _answers = <_AnswerControllers>[];
  String? _correctAnswerId;
  var _disabled = false;
  var _loaded = false;
  var _saving = false;

  String get projectId => ref.read<String>(currentProjectIdProvider);
  String? get questionId => widget.questionId;

  static const _answerIds = ['A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    FsQuestion? question;
    var questionId = this.questionId;
    if (questionId != null) {
      var db = ref.read(quizzDatabaseProvider(projectId));
      question = await db.fsQuestion(questionId).get(db.firestore);
    }
    _textEn.text = question?.text.v?.en.v ?? '';
    _textFr.text = question?.text.v?.fr.v ?? '';
    _tags.text = question?.tags.v?.join(', ') ?? '';
    _disabled = question?.disabled.v ?? false;
    _correctAnswerId = question?.correctAnswerId.v;
    var answers = question?.answers.v ?? <CvAnswer>[];
    for (var answer in answers) {
      _answers.add(_AnswerControllers(answer.id.v ?? '', answer));
    }
    while (_answers.length < 2) {
      _addAnswer();
    }
    _correctAnswerId ??= _answers.first.id;
    if (mounted) {
      setState(() {
        _loaded = true;
      });
    }
  }

  void _addAnswer() {
    var used = _answers.map((e) => e.id).toSet();
    var id = _answerIds.firstWhere(
      (id) => !used.contains(id),
      orElse: () => '${_answers.length + 1}',
    );
    _answers.add(_AnswerControllers(id, null));
  }

  @override
  void dispose() {
    _textEn.dispose();
    _textFr.dispose();
    _tags.dispose();
    for (var answer in _answers) {
      answer.dispose();
    }
    super.dispose();
  }

  FsQuestion _buildQuestion() {
    var tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return FsQuestion()
      ..text.v = (CvLocalizedText()
        ..en.setValue(quizzNonEmptyTrimmed(_textEn.text))
        ..fr.setValue(quizzNonEmptyTrimmed(_textFr.text)))
      ..answers.v = _answers
          .map(
            (answer) => CvAnswer()
              ..id.v = answer.id
              ..text.v = (CvLocalizedText()
                ..en.setValue(quizzNonEmptyTrimmed(answer.en.text))
                ..fr.setValue(quizzNonEmptyTrimmed(answer.fr.text))),
          )
          .toList()
      ..correctAnswerId.v = _correctAnswerId
      ..tags.setValue(tags.isEmpty ? null : tags)
      ..disabled.setValue(_disabled ? true : null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
    });
    try {
      var db = ref.read(quizzDatabaseProvider(projectId));
      var question = _buildQuestion();
      var questionId = this.questionId;
      if (questionId == null) {
        await db.addQuestion(question);
      } else {
        var existing = await db.fsQuestion(questionId).get(db.firestore);
        question.lastPlayedTimestamp.setValue(existing.lastPlayedTimestamp.v);
        await db.setQuestion(questionId, question);
      }
      if (mounted) {
        context.popOrGoPath(quizzHomePath);
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    var questionId = this.questionId;
    if (questionId == null) {
      return;
    }
    var confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete the question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(quizzDatabaseProvider(projectId)).deleteQuestion(questionId);
    if (mounted) {
      context.popOrGoPath(quizzHomePath);
    }
  }

  String? _validateText(String? value) {
    if ((quizzNonEmptyTrimmed(_textEn.text) ??
            quizzNonEmptyTrimmed(_textFr.text)) ==
        null) {
      return 'Enter the question in at least one language';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: RouteUpBackButton(upPath: quizzHomePath),
        title: Text(questionId == null ? 'New question' : 'Edit question'),
        actions: [
          if (questionId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _delete,
            ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: RadioGroup<String>(
                groupValue: _correctAnswerId,
                onChanged: (value) {
                  setState(() {
                    _correctAnswerId = value;
                  });
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextFormField(
                          controller: _textEn,
                          decoration: const InputDecoration(
                            labelText: 'Question (en)',
                          ),
                          validator: _validateText,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _textFr,
                          decoration: const InputDecoration(
                            labelText: 'Question (fr)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Answers (pick the correct one)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (var answer in _answers)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Radio<String>(value: answer.id),
                                  Text(
                                    answer.id,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        TextFormField(
                                          controller: answer.en,
                                          decoration: const InputDecoration(
                                            labelText: 'Answer (en)',
                                            isDense: true,
                                          ),
                                        ),
                                        TextFormField(
                                          controller: answer.fr,
                                          decoration: const InputDecoration(
                                            labelText: 'Answer (fr)',
                                            isDense: true,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: _answers.length <= 2
                                        ? null
                                        : () {
                                            setState(() {
                                              _answers.remove(answer);
                                              if (_correctAnswerId ==
                                                  answer.id) {
                                                _correctAnswerId =
                                                    _answers.first.id;
                                              }
                                            });
                                            answer.dispose();
                                          },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _answers.length >= _answerIds.length
                                ? null
                                : () {
                                    setState(_addAnswer);
                                  },
                            icon: const Icon(Icons.add),
                            label: const Text('Add an answer'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _tags,
                          decoration: const InputDecoration(
                            labelText: 'Tags (comma separated)',
                          ),
                        ),
                        SwitchListTile(
                          value: _disabled,
                          onChanged: (value) {
                            setState(() {
                              _disabled = value;
                            });
                          },
                          title: const Text('Disabled (never picked)'),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: const Text('Save'),
                        ),
                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
