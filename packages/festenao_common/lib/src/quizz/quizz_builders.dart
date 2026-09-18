import 'model/quizz_api_models.dart';
import 'model/quizz_gd_fs_models.dart';
import 'model/quizz_prefs_models.dart';

/// Registers every quizz cv model (firestore, gd, api, prefs), idempotent.
void initQuizzBuilders() {
  initQuizzGdFsBuilders();
  initQuizzApiBuilders();
  initQuizzPrefsBuilders();
}
