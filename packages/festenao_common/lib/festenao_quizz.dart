/// Quizz: a timed multiple choice quiz.
///
/// Two flavors share the same models: a **tv** quiz, displayed on a screen
/// and driven by an admin (every player answers the same question at the
/// same time, the 3 first players are validated and ranked), and a **gd**
/// quiz, played alone on a device with a random question set and a goodie to
/// win.
///
/// - the cv models ([FsQuestion], [FsQuiz], [FsQuizStatus], [FsQuizPlayer],
///   [FsSession], the gd goodies), the correct answers being encrypted in the
///   quiz document ([quizzSetModelEncryptionPassword]);
/// - [QuizzFirestoreDatabase], the firestore layer under an optional root
///   document ([festenaoProjectQuizzRootDocument] for a festenao project);
/// - [QuizPlayerController] and its [QuizRunnerState]/[QuizPlayerStateNow],
///   the live state machine used by the admin, the tv and the players;
/// - [QuizzApiClient] and [QuizzServerHandler], the api sending a player
///   result ([apiCommandQuizzSendResult]) and scoring it server side;
/// - [QuizzTimeService], the server synchronized clock;
/// - [QuizzPrefsService], the local player status.
library;

export 'src/quizz/model/quizz_api_models.dart';
export 'src/quizz/model/quizz_fs_models.dart';
export 'src/quizz/model/quizz_gd_fs_models.dart';
export 'src/quizz/model/quizz_prefs_models.dart';
export 'src/quizz/quizz_api_client.dart';
export 'src/quizz/quizz_avatar.dart';
export 'src/quizz/quizz_builders.dart';
export 'src/quizz/quizz_constant.dart';
export 'src/quizz/quizz_encrypt.dart';
export 'src/quizz/quizz_firestore_database.dart';
export 'src/quizz/quizz_key_utils.dart';
export 'src/quizz/quizz_player.dart';
export 'src/quizz/quizz_prefs_service.dart';
export 'src/quizz/quizz_progress_controller.dart';
export 'src/quizz/quizz_server_handler.dart';
export 'src/quizz/quizz_text.dart';
export 'src/quizz/quizz_time_service.dart';
