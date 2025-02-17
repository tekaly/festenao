import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/goodie/goodie_controller.dart';
import 'package:festenao_common/goodie/goodie_model.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

Future<void> main() async {
  late Firestore firestore;
  setUp(() async {
    firestore = newFirestoreMemory(); // .debugQuickLoggerWrapper();
  });
  test('playerWinRandomGoodie', () async {
    var sessionId = 'session_test_1';
    var controller = GoodieController(
        firestore: firestore, firestorePath: 'session/$sessionId');
    var now = DateTime.utc(2024, 1, 1);

    expect(
      await controller.findRandomGoodie(
        now: now,
      ),
      isNull,
    );
    var config = controller.fsGoodiesConfigRef.cv()
      ..goodies.v = [
        CvGoodieConfig()
          ..id.v = 'g1'
          ..dailyQuantity.v = 1,
      ]
      ..winningChance.v = 1;
    await firestore.cvSet(config);
    var goodie = await controller.findRandomGoodie(
      now: now,
    );
    expect(goodie, 'g1');
    expect(
      await controller.fsGoodiesStateRef.get(firestore),
      FsGoodiesState()
        ..goodies.v = [
          CvGoodieState()
            ..id.v = 'g1'
            ..count.v = 1
            ..used.v = 1,
        ],
    );
    expect(
      await controller.findRandomGoodie(
        now: now,
      ),
      isNull,
    );
  });
  test('multi playerWinRandomGoodie', () async {
    var now = DateTime.utc(2024, 1, 3);
    var sessionId = 'session_test_2';
    var controller = GoodieController(
        firestore: firestore, firestorePath: 'session/$sessionId');

    expect(
      await controller.findRandomGoodie(
        now: now,
      ),
      isNull,
    );

    var config = controller.fsGoodiesConfigRef.cv()
      ..goodies.v = [
        CvGoodieConfig()
          ..id.v = 'g1'
          ..dailyQuantity.v = 2,
        CvGoodieConfig()
          ..id.v = 'g2'
          ..dailyQuantity.v = 3,
      ]
      ..winningChance.v = 1;
    await firestore.cvSet(config);
    var goodies = <String?>[];
    for (var i = 0; i < 6; i++) {
      var goodie = await controller.findRandomGoodie(
        now: now,
      );
      goodies.add(goodie);
    }
    // ignore: avoid_print
    print(goodies);
    expect(goodies.last, isNull);
    expect(goodies.where((element) => element == 'g1').length, 2);
    expect(goodies.where((element) => element == 'g2').length, 3);
    var state = await controller.fsGoodiesStateRef.get(firestore);
    // ignore: avoid_print
    print(state);
  });
}
