import 'model/quizz_prefs_models.dart';

/// Where a player keeps its local quiz status and copy (prefs on a device,
/// memory in tests and for the admin/tv controllers).
abstract interface class QuizzPrefsService {
  /// The local status, null if none.
  PrefsQuizLocalStatus? prefsGetQuizLocalStatus();

  /// Sets (or clears) the local status.
  void prefsSetQuizLocalStatus(PrefsQuizLocalStatus? quizLocalStatus);

  /// The local copy, null if none.
  PrefsQuizLocalCopy? prefsGetQuizLocalCopy();

  /// Sets (or clears) the local copy.
  void prefsSetQuizLocalCopy(PrefsQuizLocalCopy? quizCopy);
}

/// Prefs helpers.
extension QuizzPrefsServiceExt on QuizzPrefsService {
  /// The local status of [quizId], created (and any other quiz status
  /// discarded) if needed.
  PrefsQuizLocalStatus prefsGetOrCreateQuizLocalStatus({
    required String quizId,
  }) {
    var status = prefsGetQuizLocalStatus();
    if (status?.quizId.v != quizId) {
      status = PrefsQuizLocalStatus()..quizId.v = quizId;
      prefsSetQuizLocalStatus(status);
    }
    return status!;
  }

  /// The local copy of [quizId], created (and any other quiz copy discarded)
  /// if needed.
  PrefsQuizLocalCopy prefsGetOrCreateQuizLocalCopy({required String quizId}) {
    var status = prefsGetQuizLocalCopy();
    if (status?.quizId.v != quizId) {
      status = PrefsQuizLocalCopy()..quizId.v = quizId;
      prefsSetQuizLocalCopy(status);
    }
    return status!;
  }

  /// Updates the local status if any and saves it.
  PrefsQuizLocalStatus? prefsUpdateQuizLocalStatus(
    void Function(PrefsQuizLocalStatus status) update,
  ) {
    var status = prefsGetQuizLocalStatus();
    if (status == null) {
      return null;
    }
    update(status);
    prefsSetQuizLocalStatus(status);
    return status;
  }

  /// Updates the local copy if any and saves it.
  PrefsQuizLocalCopy? prefsUpdateQuizLocalCopy(
    void Function(PrefsQuizLocalCopy status) update,
  ) {
    var copy = prefsGetQuizLocalCopy();
    if (copy == null) {
      return null;
    }
    update(copy);
    prefsSetQuizLocalCopy(copy);
    return copy;
  }

  /// Clears the local status and copy.
  void prefsClearQuiz() {
    prefsSetQuizLocalStatus(null);
    prefsSetQuizLocalCopy(null);
  }
}

/// In memory prefs.
class QuizzPrefsServiceMemory implements QuizzPrefsService {
  /// The local status.
  PrefsQuizLocalStatus? quizLocalStatus;

  /// The local copy.
  PrefsQuizLocalCopy? quizLocalCopy;

  @override
  PrefsQuizLocalStatus? prefsGetQuizLocalStatus() {
    return quizLocalStatus;
  }

  @override
  void prefsSetQuizLocalStatus(PrefsQuizLocalStatus? quizLocalStatus) {
    this.quizLocalStatus = quizLocalStatus;
  }

  @override
  PrefsQuizLocalCopy? prefsGetQuizLocalCopy() {
    return quizLocalCopy;
  }

  @override
  void prefsSetQuizLocalCopy(PrefsQuizLocalCopy? quizCopy) {
    quizLocalCopy = quizCopy;
  }
}
