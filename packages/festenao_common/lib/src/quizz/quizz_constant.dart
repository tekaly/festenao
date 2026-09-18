import 'package:tekartik_common_utils/env_utils.dart';

/// Quiz type: general knowledge ("gd") quiz played alone on a device, each
/// player getting its own random question set and possibly winning a goodie.
const quizTypeGd = 'gd';

/// Quiz type: timed quiz displayed on a tv/screen and controlled by an admin,
/// every player answering the same question at the same time.
const quizTypeTv = 'tv';

/// Quiz status: created, not started yet.
const quizStatusIdle = 'idle';

/// Quiz status: playing (players should listen to the start timestamp).
const quizStatusPlaying = 'playing';

/// Quiz status: paused.
const quizStatusPaused = 'paused';

/// Quiz status: cancelled.
const quizStatusCancelled = 'cancelled';

/// Quiz status: done, the ranking has been computed.
const quizStatusDone = 'done';

/// Quiz status: archived (after done).
const quizStatusArchived = 'archived';

/// Only valid status for a gd quiz once started.
const gdQuizStatusPlaying = quizStatusPlaying;

/// Player validity: not validated yet.
const quizPlayerValidityUnknown = 0;

/// Player validity: validated by the admin.
const quizPlayerValidityValid = 1;

/// Player validity: rejected by the admin.
const quizPlayerValidityInvalid = -1;

/// The default session id.
const sessionIdMain = '_main';

/// The test session id.
const sessionIdTest = '_test';

/// The test quiz id.
const quizIdTest = 'test';

/// The main quiz id (gd quiz).
const quizIdMain = 'main';

/// The default goodie id used in tests.
const wonGoodie1 = 'goodie1';

/// The tag of the test questions.
const quizzTestTag = 'test';

/// The default data id of the quizz data of a project
/// (`app/<app>/project/<projectId>/data/quizz`).
const quizzDefaultDataId = 'quizz';

/// Api command: a player sends its answers.
const apiCommandQuizzSendResult = 'quizz/send_result';

/// Default delay before the first question (qr code display), in ms.
var quizConfigPreDelayMsDefault = 60000;

/// Default pause between two questions, in ms.
var quizConfigPauseDelayMsDefault = 3000;

/// Default delay to answer a question, in ms.
var quizConfigAnswerDelayMsDefault = 15000;

/// Default delay to validate the players at the end, in ms.
var quizConfigValidationDelayMsDefault = 10000;

/// Default question count of a quiz.
var quizConfigQuestionCountDefault = 10;

/// A quiz is considered expired this long after its end, in ms.
final quizAutoCancelDelayMs = isDebug ? 5 * 60 * 1000 : 30 * 60 * 1000;

/// Firestore sub collection: the questions.
const quizzFsQuestionsCollectionId = 'questions';

/// Firestore sub collection: the quizzes.
const quizzFsQuizzesCollectionId = 'quizzes';

/// Firestore sub collection: the archived quizzes.
const quizzFsArchivedQuizzesCollectionId = 'archived_quizzes';

/// Firestore sub collection: the sessions.
const quizzFsSessionsCollectionId = 'sessions';

/// Firestore sub collection: the infos (config, status...).
const quizzFsInfosCollectionId = 'infos';

/// Firestore sub collection: the players of a quiz or a session.
const quizzFsPlayersCollectionId = 'players';

/// Firestore sub collection: the controllers of a quiz.
const quizzFsControllersCollectionId = 'controllers';

/// Firestore sub collection: the daily goodies states of a session.
const quizzFsGoodiesStatesCollectionId = 'goodiesStates';

/// Firestore info document: the quiz config.
const quizzFsQuizConfigDocId = 'quiz_config';

/// Firestore info document: the quiz status.
const quizzFsStatusDocId = 'status';

/// Firestore info document: the goodies config of a session.
const quizzFsGoodiesConfigDocId = 'goodiesConfig';
