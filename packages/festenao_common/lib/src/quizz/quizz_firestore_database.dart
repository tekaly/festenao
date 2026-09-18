import 'dart:math';

import 'package:sembast/utils/key_utils.dart';
import 'package:tekartik_app_date/calendar_day.dart';
import 'package:tekartik_app_date/time_offset.dart';

import 'import.dart';
import 'model/quizz_api_models.dart';
import 'model/quizz_fs_models.dart';
import 'model/quizz_gd_fs_models.dart';
import 'quizz_constant.dart';
import 'quizz_key_utils.dart';
import 'quizz_player.dart';

/// The root document of the quizz data of a festenao project:
/// `app/<app>/project/<projectId>/data/<dataId>`.
///
/// Sitting in the `data` subtree of the project, it follows the project
/// access rules: members read it, writers write it, anyone reads it when the
/// project is public.
CvDocumentReference<CvFirestoreDocument> festenaoProjectQuizzRootDocument({
  required String app,
  required String projectId,
  String? dataId,
}) => CvDocumentReference<CvFirestoreDocument>(
  'app/$app/project/$projectId/data/${dataId ?? quizzDefaultDataId}',
);

/// The quizz firestore database: questions, quizzes, sessions and players,
/// under an optional [rootDocument] (`questions`, `quizzes`... are then its
/// sub collections, top level collections otherwise).
///
/// Used by the admin (create/start/pause a quiz), the tv (display), the
/// players (read the quiz and its status) and the server (save the results).
class QuizzFirestoreDatabase {
  /// The firestore.
  final Firestore firestore;

  /// The root document, null for top level collections.
  final CvDocumentReference? rootDocument;

  /// Creates a database.
  QuizzFirestoreDatabase({required this.firestore, this.rootDocument}) {
    initQuizzGdFsBuilders();
  }

  CvCollectionReference<T> _collection<T extends CvFirestoreDocument>(
    String id,
  ) {
    var rootDocument = this.rootDocument;
    if (rootDocument == null) {
      return CvCollectionReference<T>(id);
    }
    return rootDocument.collection<T>(id);
  }

  /// `questions`
  CvCollectionReference<FsQuestion> get fsQuestionCollection =>
      _collection<FsQuestion>(quizzFsQuestionsCollectionId);

  /// `sessions`
  CvCollectionReference<FsSession> get fsSessionCollection =>
      _collection<FsSession>(quizzFsSessionsCollectionId);

  /// `infos`
  CvCollectionReference<CvFirestoreDocument> get fsInfoCollection =>
      _collection<CvFirestoreDocument>(quizzFsInfosCollectionId);

  /// `infos/quiz_config`
  CvDocumentReference<FsQuizConfig> get fsConfig =>
      fsInfoCollection.cast<FsQuizConfig>().doc(quizzFsQuizConfigDocId);

  /// `quizzes`
  CvCollectionReference<FsQuiz> get fsQuizCollection =>
      _collection<FsQuiz>(quizzFsQuizzesCollectionId);

  /// `archived_quizzes`
  CvCollectionReference<FsQuizArchive> get fsQuizArchiveCollection =>
      _collection<FsQuizArchive>(quizzFsArchivedQuizzesCollectionId);

  /// `sessions/{sessionId}`
  CvDocumentReference<FsSession> fsSession(String sessionId) =>
      fsSessionCollection.doc(sessionId);

  /// `sessions/{sessionId}/infos`
  CvCollectionReference<CvFirestoreDocument> fsSessionInfoCollection(
    String sessionId,
  ) => fsSession(
    sessionId,
  ).collection<CvFirestoreDocument>(quizzFsInfosCollectionId);

  /// `sessions/{sessionId}/infos/goodiesConfig`
  CvDocumentReference<FsGdGoodiesConfig> fsSessionGoodiesConfig(
    String sessionId,
  ) => fsSessionInfoCollection(
    sessionId,
  ).cast<FsGdGoodiesConfig>().doc(quizzFsGoodiesConfigDocId);

  /// `sessions/{sessionId}/goodiesStates`
  CvCollectionReference<FsGdGoodiesState> fsSessionGoodiesStateCollection(
    String sessionId,
  ) => fsSession(
    sessionId,
  ).collection<FsGdGoodiesState>(quizzFsGoodiesStatesCollectionId);

  /// `sessions/{sessionId}/goodiesStates/{day}`
  CvDocumentReference<FsGdGoodiesState> fsSessionGoodiesState(
    String sessionId,
    CalendarDay day,
  ) => fsSessionGoodiesStateCollection(sessionId).doc(day.text);

  /// `sessions/{sessionId}/players`
  CvCollectionReference<FsGdQuizPlayer> fsGdQuizPlayerCollection(
    String sessionId,
  ) => fsSession(
    sessionId,
  ).collection<FsGdQuizPlayer>(quizzFsPlayersCollectionId);

  /// `sessions/{sessionId}/players/{playerId}`
  CvDocumentReference<FsGdQuizPlayer> fsGdQuizPlayer(
    String sessionId,
    String playerId,
  ) => fsGdQuizPlayerCollection(sessionId).doc(playerId);

  /// `questions/{questionId}`
  CvDocumentReference<FsQuestion> fsQuestion(String questionId) =>
      fsQuestionCollection.doc(questionId);

  /// `quizzes/{quizId}`
  CvDocumentReference<FsQuiz> fsQuiz(String quizId) =>
      fsQuizCollection.doc(quizId);

  /// `quizzes/{quizId}/players`
  CvCollectionReference<FsQuizPlayer> fsQuizPlayerCollection(String quizId) =>
      fsQuiz(quizId).collection<FsQuizPlayer>(quizzFsPlayersCollectionId);

  /// `quizzes/{quizId}/players/{playerId}`
  CvDocumentReference<FsQuizPlayer> fsQuizPlayer(
    String quizId,
    String playerId,
  ) => fsQuizPlayerCollection(quizId).doc(playerId);

  /// `quizzes/{quizId}/controllers`
  CvCollectionReference<FsQuizController> fsQuizControllerCollection(
    String quizId,
  ) => fsQuiz(
    quizId,
  ).collection<FsQuizController>(quizzFsControllersCollectionId);

  /// `quizzes/{quizId}/controllers/{controllerId}`
  CvDocumentReference<FsQuizController> fsQuizController(
    String quizId,
    String controllerId,
  ) => fsQuizControllerCollection(quizId).doc(controllerId);

  /// `quizzes/{quizId}/infos`
  CvCollectionReference<CvFirestoreDocument> fsQuizInfoCollection(
    String quizId,
  ) => fsQuiz(quizId).collection<CvFirestoreDocument>(quizzFsInfosCollectionId);

  /// `quizzes/{quizId}/infos/status`
  CvDocumentReference<FsQuizStatus> fsQuizInfoStatus(String quizId) =>
      fsQuizInfoCollection(quizId).cast<FsQuizStatus>().doc(quizzFsStatusDocId);

  /// Reads the quiz and its status once.
  Future<QuizRunnerState> getQuizRunnerState(String quizId) async {
    var quiz = await fsQuiz(quizId).get(firestore);
    var quizStatus = await fsQuizInfoStatus(quizId).get(firestore);
    var cache = QuizRunnerStateCache.typed(quiz: quiz);

    var state = QuizRunnerState.typed(cache, quizStatus);
    return state;
  }

  /// Saves a player result directly (no api), returning the player id.
  Future<String> savePlayerQuizResult(
    FsQuiz quiz,
    ApiQuizzSendResultQuery apiRequest,
  ) async {
    var quizId = quiz.id;

    var score = 0;
    var elapsedMs = 0;
    if (apiRequest.answers.isNotNull) {
      for (var answer in apiRequest.answers.v!) {
        var questionId = answer.questionId.v!;
        var answerId = answer.answerId.v!;

        var correctAnswerId = quiz.getQuestionCorrectAnswerId(questionId);

        // Correct?
        if (correctAnswerId == answerId) {
          score++;
          elapsedMs += answer.elapsedMs.v!;
        }
      }
    }
    var quizPlayerCollection = fsQuizPlayerCollection(quizId);
    var player = FsQuizPlayer()
      ..username.fromCvField(apiRequest.username)
      ..avatar.fromCvField(apiRequest.avatar)
      ..score.v = score
      ..elapsedMs.v = elapsedMs;
    // Look for duplicate first
    var foundPlayer = await quizPlayerCollection
        .query()
        .where(fsQuizPlayerModel.username.name, isEqualTo: player.username.v)
        .where(fsQuizPlayerModel.avatar.name, isEqualTo: player.avatar.v)
        .where(fsQuizPlayerModel.score.name, isEqualTo: player.score.v)
        .where(fsQuizPlayerModel.elapsedMs.name, isEqualTo: player.elapsedMs.v)
        .limit(1)
        .get(firestore);
    String playerId;
    if (foundPlayer.isNotEmpty) {
      playerId = foundPlayer.first.id;
    } else {
      var ref = await quizPlayerCollection.add(firestore, player);
      playerId = ref.id;
    }
    return playerId;
  }

  /// Saves a player.
  Future<void> quizSavePlayer(String quizId, FsQuizPlayer player) async {
    await fsQuizPlayer(quizId, player.id).set(firestore, player);
  }

  /// The questions, optionally filtered by [tags].
  Stream<List<FsQuestion>> questionsStream({List<String>? tags}) {
    return questionsQuery(tags: tags).cvOnSnapshots<FsQuestion>();
  }

  /// The questions query, optionally filtered by [tags].
  Query questionsQuery({List<String>? tags}) {
    var query = fsQuestionCollection.raw(firestore).limit(1000);
    if (tags != null) {
      query = query.where(fsQuestionModel.tags.name, arrayContainsAny: tags);
    }

    return query;
  }

  /// The questions, once.
  Future<List<FsQuestion>> getQuestions({List<String>? tags}) async {
    return (await questionsQuery(tags: tags).cvGet<FsQuestion>()).toList();
  }

  /// Adds a question, returning its id.
  Future<String> addQuestion(FsQuestion question) async {
    question.lastPlayedTimestamp.v ??= neverPlayedTimestamp;
    var ref = await fsQuestionCollection.add(firestore, question);
    return ref.id;
  }

  /// Sets a question.
  Future<void> setQuestion(String questionId, FsQuestion question) async {
    question.lastPlayedTimestamp.v ??= neverPlayedTimestamp;
    await fsQuestion(questionId).set(firestore, question);
  }

  /// Deletes a question.
  Future<void> deleteQuestion(String questionId) async {
    await fsQuestion(questionId).delete(firestore);
  }

  /// The quizzes, most recent first.
  Stream<List<FsQuiz>> quizStream({int limit = 1000}) {
    var query = fsQuizCollection
        .query()
        .orderBy(fsQuizModel.createdTimestamp.name, descending: true)
        .limit(limit);
    return query.onSnapshots(firestore);
  }

  /// The quiz status.
  Stream<FsQuizStatus> quizStatusStream(String quizId) =>
      fsQuizInfoStatus(quizId).onSnapshot(firestore);

  /// The sessions.
  Stream<List<FsSession>> sessionsStream() =>
      fsSessionCollection.onSnapshots(firestore);

  /// Creates and starts a gd quiz.
  Future<FsQuiz> createPlayableGdQuiz({
    required DateTime now,
    String? sessionId,
    FsQuizConfig? config,
    int? limit,
    String? quizId,
    required String controllerId,
    @visibleForTesting String? uid,
    List<String>? tags,
  }) async {
    quizId ??= quizIdMain;
    var quiz = await createGdQuiz(
      now: now,
      sessionId: sessionId,
      config: config,
      limit: limit,
      quizId: quizId,
      uid: uid,
      tags: tags,
    );
    await startQuiz(quizId: quizId, now: now, controllerId: controllerId);

    return quiz;
  }

  /// Creates a gd quiz (all the questions, each device picking its own).
  Future<FsQuiz> createGdQuiz({
    required DateTime now,
    String? sessionId,
    FsQuizConfig? config,
    int? limit,
    String? quizId,
    @visibleForTesting String? uid,
    List<String>? tags,
  }) async {
    quizId ??= quizIdMain;
    var quiz = await _createQuiz(
      type: quizTypeGd,
      now: now,
      sessionId: sessionId,
      limit: limit ?? 500,
      config: config,
      uid: uid,
      ignoreAlreadyPlayed: true,
      quizId: quizId,
      tags: tags,
    );
    return quiz;
  }

  /// Creates a tv quiz (the least recently played questions, shuffled).
  Future<FsQuiz> createTvQuiz({
    required DateTime now,
    String? quizId,
    String? sessionId,
    FsQuizConfig? config,
    @visibleForTesting String? uid,
  }) => _createQuiz(
    now: now,
    type: quizTypeTv,
    quizId: quizId,
    sessionId: sessionId,
    config: config,
    uid: uid,
  );

  Future<FsQuiz> _createQuiz({
    required DateTime now,
    required String type,
    String? sessionId,
    FsQuizConfig? config,
    int? limit,
    String? quizId,
    @visibleForTesting String? uid,
    bool? ignoreAlreadyPlayed,
    List<String>? tags,
  }) async {
    sessionId ??= sessionIdMain;

    config ??= await fsConfig.get(firestore);
    tags ??= config.tags.v;

    var timestamp = Timestamp.fromDateTime(now);
    Query query = fsQuestionCollection.raw(firestore);
    if (type != quizTypeGd) {
      limit ??= 50;
      query = query.orderBy(fsQuestionModel.lastPlayedTimestamp.name);
    } else {
      limit ??= 500;
      query = query.orderById();
    }

    if (tags != null) {
      query = query.where(fsQuestionModel.tags.name, arrayContainsAny: tags);
    }
    var questions = (await query.limit(limit).cvGet<FsQuestion>())
        .where((question) => question.disabled.v != true)
        .toList();

    if (questions.isEmpty) {
      // Set to 0 only in tests.
      if (config.questionCount.v != 0) {
        throw StateError('No questions');
      }
    }
    if (ignoreAlreadyPlayed ?? false) {
    } else {
      var dateLimit = now.subtract(const Duration(hours: 12));
      // Delete the latest questions if less then 12 hours
      while (true) {
        if (questions.length < 21) {
          break;
        }
        var last = questions.last;
        if (last.lastPlayedTimestamp.v!.toDateTime().isAfter(dateLimit)) {
          questions.removeLast();
        } else {
          break;
        }
      }
    }
    var quiz = FsQuiz()
      ..type.v = type
      ..uid.v = uid ?? generateStringKey()
      ..createdTimestamp.v = timestamp
      ..sessionId.v = sessionId;
    quiz.copyConfigFrom(config);

    var pickedQuestions = <FsQuestion>[];
    if (quiz.isTypeGd) {
      quiz.questions.v = questions.map((e) => e.toEncoded()).toList();
    } else {
      var random = Random(now.millisecondsSinceEpoch);
      questions.shuffle(random);
      var count = (config.questionCount.v ?? quizConfigQuestionCountDefault)
          .boundedMax(questions.length);
      pickedQuestions = questions.sublist(0, count);
      quiz.questions.v = pickedQuestions.map((e) => e.toEncoded()).toList();

      if (pickedQuestions.isEmpty) {
        // Set to 0 only in tests.
        if (config.questionCount.v != 0) {
          throw StateError('No questions');
        }
      }
    }

    var enforcedQuizId = quizId;
    await firestore.cvRunTransaction((transaction) async {
      String path;
      if (enforcedQuizId != null) {
        path = fsQuiz(enforcedQuizId).path;
      } else {
        while (true) {
          var quizId = generateQuizKey();
          path = fsQuiz(quizId).path;
          if (!(await transaction.cvGet<FsQuiz>(path)).exists) {
            break;
          }
        }
      }

      quiz.path = path;
      var quizId = quiz.id;
      transaction.cvSet(quiz);
      transaction.cvSet(
        fsQuizInfoStatus(quizId).cv()..status.v = quizStatusIdle,
      );
      for (var question in pickedQuestions) {
        transaction.cvUpdate(
          FsQuestion()
            ..path = question.path
            ..lastPlayedTimestamp.v = timestamp,
        );
      }
    });
    return quiz;
  }

  /// Takes ownership of the quiz.
  Future<void> controlQuiz({
    required String quizId,
    required String controllerId,
  }) async {
    var quizStatus = FsQuizStatus()..controllerId.v = controllerId;
    await fsQuizInfoStatus(quizId).update(firestore, quizStatus);
  }

  /// Cancels a quiz (only if not done yet) and clears it from its session.
  Future<void> cancelQuiz({required String quizId}) async {
    var quiz = await fsQuiz(quizId).get(firestore);
    var existingQuizStatus = await fsQuizInfoStatus(quizId).get(firestore);

    /// Don't cancel if already done.
    if (existingQuizStatus.canBeCancelled) {
      var quizStatus = FsQuizStatus()
        ..pausedStartTimestamp.setNull()
        ..status.v = quizStatusCancelled;
      try {
        await fsQuizInfoStatus(quizId).update(firestore, quizStatus);
      } catch (e) {
        // ignore: avoid_print
        print('$e quiz update failed for cancel, ok...');
      }
    }

    var sessionId = quiz.sessionId.v;

    if (sessionId != null) {
      var session = await fsSession(sessionId).get(firestore);
      if (session.activeQuizId.v == quizId) {
        await fsSession(sessionId).set(
          firestore,
          FsSession()..activeQuizId.v = null,
          SetOptions(merge: true),
        );
      }
    }
  }

  /// Cancels the active quiz of a session, if any.
  Future<void> cancelActiveQuiz({required String sessionId}) async {
    var session = await fsSession(sessionId).get(firestore);
    var quizId = session.activeQuizId.v;
    if (quizId != null) {
      await cancelQuiz(quizId: quizId);
    }
  }

  Future<void> _waitForQuizOnline({required String quizId}) async {
    if (firestore.service.supportsDocumentSnapshotTime &&
        firestore.service.supportsTrackChanges) {
      var completer = Completer<bool>();
      var subscription = fsQuiz(quizId)
          .raw(firestore)
          .onSnapshot(includeMetadataChanges: true)
          .listen((event) {
            if (!event.exists) {
              throw StateError('Quiz $quizId not present');
            }
            if (!event.metadata.hasPendingWrites && !completer.isCompleted) {
              completer.complete(true);
            }
          });
      try {
        await completer.future.timeout(const Duration(seconds: 15));
      } finally {
        subscription.cancel().unawait();
      }
    }
  }

  /// Writes the controller presence and waits for it to be online.
  Future<void> writeAndWaitControllerOnline({
    required String quizId,
    required String controllerId,
  }) async {
    await fsQuizController(
      quizId,
      controllerId,
    ).setMap(firestore, FsQuizController().toMapWithServerTimestamp());
    if (firestore.service.supportsDocumentSnapshotTime &&
        firestore.service.supportsTrackChanges) {
      var completer = Completer<bool>();
      var subscription = fsQuizController(quizId, controllerId)
          .raw(firestore)
          .onSnapshot(includeMetadataChanges: true)
          .listen((event) {
            if (!event.exists) {
              throw StateError('Quiz $quizId not present');
            }
            if (!event.metadata.hasPendingWrites && !completer.isCompleted) {
              completer.complete(true);
            }
          });
      try {
        await completer.future.timeout(const Duration(seconds: 60));
      } finally {
        subscription.cancel().unawait();
      }
    }
  }

  /// Makes a quiz the active (idle) quiz of its session, cancelling the
  /// current one if any.
  Future<void> makeQuizPreActive({
    required String quizId,
    required DateTime now,
    required String controllerId,
  }) async {
    var quiz = await fsQuiz(quizId).get(firestore);
    if (!quiz.exists) {
      throw StateError('Quiz $quizId does not exist');
    }
    var sessionId = quiz.sessionId.v;
    if (sessionId != null) {
      await cancelActiveQuiz(sessionId: sessionId);
    }
    var quizStatus = fsQuizInfoStatus(quizId).cv()
      ..controllerId.v = controllerId
      ..status.v = quizStatusIdle;
    await firestore.cvRunTransaction((transaction) async {
      transaction.cvSet(quizStatus);
      if (sessionId != null) {
        transaction.cvSet(
          fsSession(sessionId).cv()..activeQuizId.v = quizId,
          SetOptions(merge: true),
        );
      }
    });
    await _waitForQuizOnline(quizId: quizId);
  }

  /// Starts the active (idle) quiz at [now].
  Future<void> startActiveQuiz({
    required String quizId,
    required DateTime now,
  }) async {
    var quiz = await fsQuiz(quizId).get(firestore);
    if (!quiz.exists) {
      throw StateError('Quiz $quizId does not exist');
    }
    var quizStatus = fsQuizInfoStatus(quizId).cv()
      ..startTimestamp.v = Timestamp.fromDateTime(now)
      ..status.v = quizStatusPlaying;
    await fsQuizInfoStatus(quizId).update(firestore, quizStatus);
    await _waitForQuizOnline(quizId: quizId);
  }

  /// Starts the quiz at [now], being its controller.
  Future<void> startQuiz({
    required String quizId,
    required DateTime now,
    required String controllerId,
  }) async {
    var quiz = await fsQuiz(quizId).get(firestore);
    if (!quiz.exists) {
      throw StateError('Quiz $quizId does not exist');
    }
    if (quiz.isTypeGd) {
      var quizStatus = await fsQuizInfoStatus(quizId).get(firestore);
      if (!(quizStatus.isPlaying)) {
        quizStatus = fsQuizInfoStatus(quizId).cv()
          ..controllerId.v = controllerId
          ..startTimestamp.v = Timestamp.fromDateTime(now)
          ..status.v = quizStatusPlaying;
        await fsQuizInfoStatus(quizId).set(firestore, quizStatus);
      }
    } else {
      var sessionId = quiz.sessionId.v;
      if (sessionId != null) {
        await cancelActiveQuiz(sessionId: sessionId);
      }
      var quizStatus = fsQuizInfoStatus(quizId).cv()
        ..controllerId.v = controllerId
        ..startTimestamp.v = Timestamp.fromDateTime(now)
        ..status.v = quizStatusPlaying;
      await firestore.cvRunTransaction((transaction) async {
        transaction.cvSet(quizStatus);
        if (sessionId != null) {
          transaction.cvSet(
            fsSession(sessionId).cv()..activeQuizId.v = quizId,
            SetOptions(merge: true),
          );
        }
      });
    }
    await _waitForQuizOnline(quizId: quizId);
  }

  /// Pauses the quiz at [now] (no-op if already paused or idle).
  Future<void> pauseQuiz({
    required String quizId,
    required DateTime now,
    FsQuizStatus? existing,
  }) async {
    var ref = fsQuizInfoStatus(quizId);
    existing ??= await ref.get(firestore);
    if (existing.isPaused || existing.isIdle) {
      return;
    }

    var quizStatus = FsQuizStatus()
      ..pausedStartTimestamp.v = Timestamp.fromDateTime(now)
      ..status.v = quizStatusPaused;
    await ref.update(firestore, quizStatus);
  }

  /// Pauses or resumes the quiz at [now].
  Future<void> togglePauseResumeQuiz({
    required String quizId,
    required DateTime now,
  }) async {
    var quizStatus = await fsQuizInfoStatus(quizId).get(firestore);
    if (!quizStatus.exists) {
      throw StateError('Quiz status $quizId does not exist');
    }
    var pauseStartTimestamp = quizStatus.pausedStartTimestamp.v;
    if (pauseStartTimestamp != null &&
        (quizStatus.isIdle || quizStatus.isPaused)) {
      await resumeQuiz(quizId: quizId, now: now);
    } else {
      await pauseQuiz(quizId: quizId, now: now);
    }
  }

  /// Resumes the quiz at [now] (if paused, or starts it if idle).
  Future<void> resumeQuiz({
    required String quizId,
    required DateTime now,
  }) async {
    // diff between pausedStartTimestamp and now should match
    var quizStatus = await fsQuizInfoStatus(quizId).get(firestore);
    if (!quizStatus.exists) {
      throw StateError('Quiz status $quizId does not exist');
    }
    var pauseStartTimestamp = quizStatus.pausedStartTimestamp.v;
    if (pauseStartTimestamp != null &&
        quizStatus.status.v == quizStatusPaused) {
      var diff = pauseStartTimestamp.toDateTime().difference(
        (quizStatus.startTimestamp.v ?? quizStatus.pausedStartTimestamp.v)!
            .toDateTime(),
      );
      var newQuizStatus = FsQuizStatus()
        ..pausedStartTimestamp.setNull()
        ..startTimestamp.v = Timestamp.fromDateTime(now.subtract(diff))
        ..status.v = quizStatusPlaying;
      await fsQuizInfoStatus(quizId).update(firestore, newQuizStatus);
    } else if (quizStatus.status.v == quizStatusIdle) {
      await startQuiz(
        quizId: quizId,
        now: now,
        controllerId: quizStatus.controllerId.v!,
      );
    }
  }

  /// The players ordered by validity, score and time.
  Query getOrderedPlayersQuery(String quizId, {int limit = 3}) {
    var query = fsQuizPlayerCollection(quizId)
        .raw(firestore)
        .orderBy(fsQuizPlayerModel.validity.name, descending: true)
        .orderBy(fsQuizPlayerModel.score.name, descending: true)
        .orderBy(fsQuizPlayerModel.elapsedMs.name)
        .limit(limit);
    return query;
  }

  /// The players ordered by score and time.
  Query getOrderedPlayersQueryNoValidity(String quizId, {int limit = 3}) {
    var query = fsQuizPlayerCollection(quizId)
        .raw(firestore)
        .orderBy(fsQuizPlayerModel.score.name, descending: true)
        .orderBy(fsQuizPlayerModel.elapsedMs.name)
        .limit(limit);
    return query;
  }

  /// The players ordered by score and time, as a stream.
  Stream<List<FsQuizPlayer>> orderedPlayersNoValidityStream(
    String quizId, {
    int limit = 100,
  }) => getOrderedPlayersQueryNoValidity(
    quizId,
    limit: limit,
  ).cvOnSnapshots<FsQuizPlayer>();

  /// The players ordered by rank, as a stream.
  Stream<List<FsQuizPlayer>> rankedPlayersStream(
    String quizId, {
    int limit = 3,
  }) => fsQuizPlayerCollection(quizId)
      .query()
      .orderBy(fsQuizPlayerModel.rank.name)
      .limit(limit)
      .onSnapshots(firestore);

  /// Validates the [limit] first players.
  Future<void> validatePlayers({required String quizId, int limit = 3}) async {
    var query = getOrderedPlayersQuery(quizId, limit: limit);
    var players = (await query.get()).docs;
    var batch = firestore.cvBatch();
    for (var i = 0; i < players.length; i++) {
      var player = players[i];
      batch.cvUpdate(
        fsQuizPlayer(quizId, player.ref.id).cv()
          ..validity.v = quizPlayerValidityValid,
      );
    }
    await batch.commit();
  }

  /// Sets the validity of a player.
  Future<void> validatePlayer({
    required String quizId,
    required String playerId,
    required int quizPlayerValidity,
  }) async {
    await firestore.cvUpdate(
      fsQuizPlayer(quizId, playerId).cv()..validity.v = quizPlayerValidity,
    );
  }

  /// True to only rank the first 3 players (default).
  var computeOnlyFirst3 = true;

  /// Computes the ranks, returning the player count.
  Future<int> computePlayersRanks({required String quizId}) async {
    var step = 50;
    var rank = 0;
    if (computeOnlyFirst3) {
      step = 3;
    }
    var query = getOrderedPlayersQuery(quizId, limit: step);

    while (true) {
      var players = (await query.get()).docs;
      if (players.isEmpty) {
        break;
      }
      var batch = firestore.cvBatch();
      for (var i = 0; i < players.length; i++) {
        var player = players[i];
        batch.cvUpdate(
          fsQuizPlayer(quizId, player.ref.id).cv()..rank.v = ++rank,
        );
      }
      await batch.commit();
      if (players.length < step) {
        break;
      }
      if (computeOnlyFirst3) {
        break;
      }
      query = query.startAfter(snapshot: players.last);
    }

    return await fsQuizPlayerCollection(quizId).count(firestore);
  }

  /// The player count.
  Future<int> quizCountPlayers(String quizId) async {
    return await fsQuizPlayerCollection(quizId).count(firestore);
  }

  /// The ordered players (validity, score, elapsedMs).
  Future<List<FsQuizPlayer>> getOrderedPlayers({
    required String quizId,
    int limit = 3,
  }) async {
    return await getOrderedPlayersQuery(
      quizId,
      limit: limit,
    ).cvGet<FsQuizPlayer>();
  }

  /// The most recent player.
  Future<FsQuizPlayer?> getMostRecentPlayer({required String quizId}) async {
    var query = fsQuizPlayerCollection(quizId)
        .query()
        .orderBy(fsQuizPlayerModel.timestamp.name, descending: true)
        .limit(3);
    return query.get(firestore).then((players) => players.firstOrNull);
  }

  /// Waits for [noNewPlayerDuration] (3 seconds by default) without new
  /// player.
  Future<void> waitForPlayerResults({
    required String quizId,
    Duration? noNewPlayerDuration,
  }) async {
    noNewPlayerDuration ??= const Duration(seconds: 3);
    Timer? doneTimer;
    FsQuizPlayer? lastReadPlayer;
    var done = false;
    while (!done) {
      await sleep(min(1000, noNewPlayerDuration.inMilliseconds));
      var player = await getMostRecentPlayer(quizId: quizId);

      if (player != null) {
        if (player.timestamp.v != lastReadPlayer?.timestamp.v) {
          lastReadPlayer = player;
          doneTimer?.cancel();
          doneTimer = null;
          continue;
        }
      }

      doneTimer ??= Timer(noNewPlayerDuration, () {
        done = true;
      });
    }
  }

  /// Shifts the quiz start by [ms] (positive: forward in the quiz).
  Future<FsQuizStatus> quizOffset({
    required String quizId,
    FsQuizStatus? quizStatus,
    required int ms,
  }) async {
    quizStatus ??= await fsQuizInfoStatus(quizId).get(firestore);
    if (!quizStatus.exists) {
      throw StateError('Quiz status $quizId does not exist');
    }
    var existingStartMs = quizStatus.startTimestamp.v!.millisecondsSinceEpoch;
    var updatedStartMs = existingStartMs - ms;
    quizStatus.startTimestamp.v = Timestamp.fromMillisecondsSinceEpoch(
      updatedStartMs,
    );

    await fsQuizInfoStatus(quizId).update(firestore, quizStatus);
    return quizStatus;
  }

  /// Deletes a quiz and all its players (archiving it first).
  Future<void> deleteQuiz(String quizId) async {
    await archiveQuiz(quizId, delete: true);
  }

  /// Finds an archive.
  Future<FsQuizArchive?> findArchive({
    required String sessionId,
    required String quizId,
    required Timestamp startTimestamp,
  }) async {
    var query = fsQuizArchiveCollection
        .query()
        .where(fsQuizArchiveModel.quizId.name, isEqualTo: quizId)
        .where(fsQuizArchiveModel.sessionId.name, isEqualTo: sessionId)
        .where(
          fsQuizArchiveModel.startTimestamp.name,
          isEqualTo: startTimestamp,
        )
        .limit(1);
    var archives = await query.get(firestore);
    return archives.firstOrNull;
  }

  /// Archives a quiz (a summary in `archived_quizzes`), deleting it when
  /// [delete] is true.
  Future<void> archiveQuiz(String quizId, {bool delete = false}) async {
    var status = await fsQuizInfoStatus(quizId).get(firestore);
    var playersCount = status.playersCount.v;
    if (playersCount != null) {
      var quiz = await fsQuiz(quizId).get(firestore);
      if (quiz.exists && !status.isArchived) {
        var startTimestamp =
            status.startTimestamp.v ?? quiz.createdTimestamp.v ?? minTimestamp;
        var sessionId = quiz.sessionId.v ?? sessionIdMain;
        var existingArchive = await findArchive(
          sessionId: sessionId,
          quizId: quizId,
          startTimestamp: startTimestamp,
        );
        if (existingArchive == null) {
          var quizArchive = FsQuizArchive()
            ..sessionId.v = sessionId
            ..quizId.v = quizId
            ..playersCount.v = playersCount
            ..startTimestamp.v = startTimestamp;
          await fsQuizArchiveCollection.add(firestore, quizArchive);
        }
      }
    }
    if (delete) {
      await deleteCollection(
        firestore,
        fsQuizPlayerCollection(quizId).raw(firestore),
        batchSize: 100,
      );
      await deleteCollection(
        firestore,
        fsQuizInfoCollection(quizId).raw(firestore),
        batchSize: 100,
      );
      await deleteCollection(
        firestore,
        fsQuizControllerCollection(quizId).raw(firestore),
        batchSize: 100,
      );
      await fsQuiz(quizId).delete(firestore);
    } else {
      if (!status.isArchived) {
        await fsQuizInfoStatus(
          quizId,
        ).update(firestore, FsQuizStatus()..status.v = quizStatusArchived);
      }
    }
  }

  /// Deletes the tv quizzes created before [maxDateTime].
  Future<void> deleteQuizzesBefore(DateTime maxDateTime) async {
    var count = 10;
    var query = fsQuizCollection
        .query()
        .where(fsQuizModel.createdTimestamp.name, isLessThan: maxDateTime)
        .limit(count);

    while (true) {
      var quizzes = await query.get(firestore);

      for (var quiz in quizzes) {
        if (quiz.isTypeGd) {
          // Do not delete gd quizzes
        } else {
          await deleteQuiz(quiz.id);
        }
      }
      if (quizzes.length < count) {
        break;
      }
    }
  }

  /// Archives the tv quizzes created before [maxDateTime].
  Future<void> archiveQuizzesBefore(DateTime maxDateTime) async {
    var count = 10;
    var query = fsQuizCollection
        .query()
        .orderBy(fsQuizModel.createdTimestamp.name)
        .where(fsQuizModel.createdTimestamp.name, isLessThan: maxDateTime)
        .limit(count);

    while (true) {
      var quizzes = await query.get(firestore);

      for (var quiz in quizzes) {
        if (quiz.isTypeGd) {
          // Do not archive gd quizzes
        } else {
          await archiveQuiz(quiz.id);
        }
      }
      if (quizzes.length < count) {
        break;
      }
      var last = quizzes.last;
      query = query.startAt(values: [last.createdTimestamp.v]);
    }
  }

  /// Cron cleanup: deletes the tv quizzes older than 28 days, archives the
  /// ones older than a day.
  Future<void> cronCleanup({DateTime? now}) async {
    now ??= DateTime.timestamp();
    await deleteQuizzesBefore(now.subtract(const Duration(days: 28)));
    await archiveQuizzesBefore(now.subtract(const Duration(days: 1)));
  }

  /// Marks the quiz as done with its player count.
  Future<void> quizUpdatePlayerCountAndMarkAsDone(
    String quizId,
    int playerCount,
  ) async {
    await fsQuizInfoStatus(quizId).update(
      firestore,
      FsQuizStatus()
        ..status.v = quizStatusDone
        ..playersCount.v = playerCount,
    );
  }

  /// Draws a goodie for a gd player, returning its id if won.
  Future<String?> playerWinRandomGoodie({
    required String sessionId,
    required DateTime now,
  }) async {
    return await firestore.cvRunTransaction((txn) async {
      return txnPlayerWinRandomGoodie(txn: txn, sessionId: sessionId, now: now);
    });
  }

  /// Draws a goodie for a gd player in a transaction, returning its id if
  /// won.
  Future<String?> txnPlayerWinRandomGoodie({
    required CvFirestoreTransaction txn,
    required String sessionId,
    required DateTime now,
  }) async {
    var config = await txn.refGet(fsSessionGoodiesConfig(sessionId));
    if (config.exists) {
      var random = Random();
      var chance = random.nextDouble();
      var winningChance = config.winningChance.v ?? 0;
      if (chance < winningChance) {
        var offset = TimeOffset.parse(config.startOfDayTimeOffset.v ?? '');
        var day = CalendarDay.fromTimestamp(
          now.subtract(Duration(milliseconds: offset.milliseconds)).toUtc(),
        );
        var stateRef = fsSessionGoodiesState(sessionId, day);
        var state = await txn.refGet(stateRef);

        if (!state.exists) {
          state = FsGdGoodiesState()
            ..path = stateRef.path
            ..goodies.v = config.goodies.v
                ?.map(
                  (e) => CvGdGoodieState()
                    ..id.v = e.id.v
                    ..count.v = e.dailyQuantity.v,
                )
                .toList();
        }
        var totalGoodieCount = state.goodies.v!.fold<int>(
          0,
          (previousValue, element) => previousValue + element.remainingCount,
        );

        var index = (chance / winningChance) * totalGoodieCount;

        var count = 0;
        String? goodieId;
        for (var i = 0; i < (state.goodies.v?.length ?? 0); i++) {
          var goodieState = state.goodies.v![i];
          count += state.goodies.v![i].remainingCount;
          if (index < count) {
            goodieId = goodieState.id.v;
            goodieState.used.v = (goodieState.used.v ?? 0) + 1;
            break;
          }
        }

        if (goodieId != null) {
          txn.cvSet(state);
          return goodieId;
        }
      }
    }

    return null;
  }
}
