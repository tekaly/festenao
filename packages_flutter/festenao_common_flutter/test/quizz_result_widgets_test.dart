import 'package:festenao_common_flutter/festenao_quizz_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// Counts the query streams created.
class _CountingDatabase extends QuizzFirestoreDatabase {
  var orderedCalls = 0;
  var rankedCalls = 0;
  var statusCalls = 0;

  _CountingDatabase({required super.firestore});

  @override
  Stream<List<FsQuizPlayer>> orderedPlayersNoValidityStream(
    String quizId, {
    int limit = 100,
  }) {
    orderedCalls++;
    return super.orderedPlayersNoValidityStream(quizId, limit: limit);
  }

  @override
  Stream<List<FsQuizPlayer>> rankedPlayersStream(
    String quizId, {
    int limit = 3,
  }) {
    rankedCalls++;
    return super.rankedPlayersStream(quizId, limit: limit);
  }

  @override
  Stream<FsQuizStatus> quizStatusStream(String quizId) {
    statusCalls++;
    return super.quizStatusStream(quizId);
  }
}

/// The memory firestore answers asynchronously: real time between pumps.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

FsQuizPlayer _player(String name, int rank, {required bool valid}) =>
    FsQuizPlayer()
      ..username.v = name
      ..rank.v = rank
      ..score.v = 3
      ..elapsedMs.v = rank * 100
      ..validity.v = valid
          ? quizPlayerValidityValid
          : quizPlayerValidityUnknown;

/// A done quiz `z1` with 2 ranked players, alice and bob.
Future<_CountingDatabase> _newDatabase() async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory();
  var database = _CountingDatabase(firestore: firestore);
  await database
      .fsQuizInfoStatus('z1')
      .set(firestore, FsQuizStatus()..playersCount.v = 2);
  await database
      .fsQuizPlayer('z1', 'p1')
      .set(firestore, _player('alice', 1, valid: true));
  await database
      .fsQuizPlayer('z1', 'p2')
      .set(firestore, _player('bob', 2, valid: true));
  return database;
}

/// [child] rebuilt every 100 ms, as under the QuizzStateNowBuilder of the
/// control and tv screens.
Widget _periodicApp(WidgetBuilder child) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 800,
      height: 600,
      child: QuizzPeriodicBuilder(builder: child),
    ),
  ),
);

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }, timeout: const Timeout(Duration(minutes: 1)));
}

void main() {
  group('query streams created once under a periodic parent', () {
    _testWidgets('QuizzValidationWidget', (tester) async {
      var database = await _newDatabase();
      var quiz = database.fsQuiz('z1').cv();
      var timeService = QuizzTimeService.local();
      await tester.pumpWidget(
        _periodicApp(
          (_) => SingleChildScrollView(
            child: QuizzValidationWidget(
              database: database,
              timeService: timeService,
              quiz: quiz,
              onEnd: () {},
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(database.orderedCalls, 1);
    });

    _testWidgets('QuizzTopPlayersWidget', (tester) async {
      var database = await _newDatabase();
      await tester.pumpWidget(
        _periodicApp(
          (_) => QuizzTopPlayersWidget(database: database, quizId: 'z1'),
        ),
      );
      await _settle(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(database.orderedCalls, 1);
    });

    _testWidgets('QuizzResultPodiumWidget', (tester) async {
      var database = await _newDatabase();
      await tester.pumpWidget(
        _periodicApp(
          (_) => QuizzResultPodiumWidget(database: database, quizId: 'z1'),
        ),
      );
      await _settle(tester);
      expect(find.text('Alice'), findsOneWidget);
      expect(database.statusCalls, 1);
      expect(database.rankedCalls, 1);
    });
  });

  _testWidgets('QuizzResultPodiumWidget follows a ranks change', (
    tester,
  ) async {
    var database = await _newDatabase();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: QuizzResultPodiumWidget(database: database, quizId: 'z1'),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('Alice'), findsOneWidget);
    // Alice no longer valid, carol validated and ranked first (a forced
    // compute of the ranks).
    await database
        .fsQuizPlayer('z1', 'p1')
        .set(database.firestore, _player('alice', 3, valid: false));
    await database
        .fsQuizPlayer('z1', 'p3')
        .set(database.firestore, _player('carol', 1, valid: true));
    await _settle(tester);
    expect(find.text('Carol'), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });
}
