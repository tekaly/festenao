import 'package:festenao_common/festenao_quizz.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  test('cleanup with more old gd quizzes than a page', () async {
    var firestore = newFirestoreMemory();
    var db = QuizzFirestoreDatabase(firestore: firestore);
    // Same creation timestamp, more than a page (10) of kept gd quizzes.
    var old = Timestamp.fromDateTime(DateTime.utc(2020));
    for (var i = 0; i < 12; i++) {
      await db.fsQuizCollection
          .doc('gd$i')
          .set(
            firestore,
            FsQuiz()
              ..type.v = quizTypeGd
              ..createdTimestamp.v = old,
          );
      await db.fsQuizCollection
          .doc('tv$i')
          .set(
            firestore,
            FsQuiz()
              ..type.v = quizTypeTv
              ..createdTimestamp.v = old,
          );
    }
    await db
        .deleteQuizzesBefore(DateTime.utc(2021))
        .timeout(const Duration(seconds: 10));
    var ids = (await db.fsQuizCollection.query().get(
      firestore,
    )).map((quiz) => quiz.id).toSet();
    expect(ids, {for (var i = 0; i < 12; i++) 'gd$i'});
    await db
        .archiveQuizzesBefore(DateTime.utc(2021))
        .timeout(const Duration(seconds: 10));
  });
}
