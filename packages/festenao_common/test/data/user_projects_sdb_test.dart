// In unit tests, by reusing our previous "createContainer" utility.

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:test/test.dart';

Future<void> main() async {
  late UserProjectsSdb db;
  setUp(() {
    db = UserProjectsSdb.inMemory();
  });
  tearDown(() async {
    await db.close();
  });
  test('user ready', () async {
    var userId = '1234';
    // await expectLater(() => db.projectUserReady(userId: userId).timeout(Duration(milliseconds: 50)), throwsA(isA<TimeoutException>()));
    expect(await db.projectsUserReady(userId: userId), isNull);
    await db.setCurrentIdentityId(userId);
    expect(await db.onProjectsUserReady(userId: userId).first, isNotNull);
  });
  test('wait for current id', () async {
    var userId = '1234';
    var userReadyStream = db.onProjectsUserReady(userId: userId);
    var completer = Completer<SdbProjectsUser?>();
    var subscription = userReadyStream.listen((data) {
      if (data != null) {
        completer.safeComplete(data);
      }
    });

    await db.setCurrentIdentityId(userId);
    expect(await completer.future, isNotNull);
    await subscription.cancel();
  });
}
