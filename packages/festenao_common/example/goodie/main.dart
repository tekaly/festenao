import 'package:festenao_common/data/calendar.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/goodie/goodie_controller.dart';
import 'package:festenao_common/goodie/goodie_model.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

Future<void> main(List<String> args) async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory().debugQuickLoggerWrapper();
  var now = DateTime.utc(2024, 1, 3);
  var sessionId = 'session_test_2';
  var controller = GoodieController(
    firestore: firestore,
    firestorePath: 'session/$sessionId',
  );
  var day = CalendarDay.fromTimestamp(now);
  var goodieId = await controller.findRandomGoodie(now: now);
  // ignore: avoid_print
  print('goodieId: $goodieId');

  var config =
      // ignore: invalid_use_of_visible_for_testing_member
      controller.fsGoodiesConfigRef.cv()
        ..goodies.v = [
          CvGoodieConfig()
            ..id.v = 'g1'
            ..quantity.v = 2,
          CvGoodieConfig()
            ..id.v = 'g2'
            ..quantity.v = 3,
        ]
        ..winningChance.v = 1;
  await firestore.cvSet(config);
  var goodies = <String?>[];
  for (var i = 0; i < 6; i++) {
    var goodie = await controller.findRandomGoodie(now: now);
    goodies.add(goodie);
  }
  // ignore: avoid_print
  print(goodies);

  var state = await controller.fsGoodiesDailyStateRef(day).get(firestore);
  // ignore: avoid_print
  print(state);
}
