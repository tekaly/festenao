import 'dart:math';

import 'package:festenao_common/data/calendar.dart';
import 'package:festenao_common/data/festenao_firestore.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:tekartik_app_date/time_offset.dart';

import 'goodie_model.dart';

/// /goodie_state/{day}
const _goodiesStateCollectionId = 'goodie_state';
const _goodieInfoCollectionPart = 'goodie_info';
const _goodiesConfigInfoDocId = 'config';
const _goodiesStateInfoDocId = 'state'; // Not in daily state

/// Simple goodie controller for managing goodie sessions and states.
class GoodieController {
  /// The Firestore instance used for database operations.
  final Firestore firestore;

  /// Top firestore path for the goodie controller.
  final String firestorePath;

  /// Creates a new [GoodieController] with the given [firestore] and [firestorePath].
  GoodieController({required this.firestore, required this.firestorePath}) {
    initFsGoodieBuilders();
  }

  late FsGoodiesConfig _lastGoodiesConfigUsed;

  /// Last goodie config used in the controller.
  FsGoodiesConfig get lastGoodiesConfigUsed => _lastGoodiesConfigUsed;

  /// Firestore reference to the goodie session document.
  @visibleForTesting
  CvDocumentReference<FsGoodieSession> get fsGoodieSessionRef =>
      _fsGoodieSessionRef;
  CvDocumentReference<FsGoodieSession> get _fsGoodieSessionRef {
    return CvDocumentReference<FsGoodieSession>(firestorePath);
  }

  /// Firestore reference to the goodies config document.
  @visibleForTesting
  CvDocumentReference<FsGoodiesConfig> get fsGoodiesConfigRef =>
      _fsGoodiesConfigRef;
  CvDocumentReference<FsGoodiesConfig> get _fsGoodiesConfigRef =>
      _fsGoodieSessionRef
          .collection<FsGoodiesConfig>(_goodieInfoCollectionPart)
          .doc(_goodiesConfigInfoDocId);

  /// Firestore reference to the goodies daily state document for the given [day].
  CvDocumentReference<FsGoodiesState> fsGoodiesDailyStateRef(CalendarDay day) =>
      _fsGoodiesDailyStateRef(day);
  CvDocumentReference<FsGoodiesState> _fsGoodiesDailyStateRef(
    CalendarDay day,
  ) => _fsGoodieSessionRef
      .collection<FsGoodiesState>(_goodiesStateCollectionId)
      .doc(day.text);

  /// Firestore reference to the goodies state document.
  CvDocumentReference<FsGoodiesState> get fsGoodiesStateRef =>
      _fsGoodiesStateRef;
  CvDocumentReference<FsGoodiesState> get _fsGoodiesStateRef =>
      _fsGoodieSessionRef
          .collection<FsGoodiesState>(_goodieInfoCollectionPart)
          .doc(_goodiesStateInfoDocId);

  /// Finds a random goodie based on the current configuration and state.
  ///
  /// Returns the goodie ID if won, or null otherwise.
  Future<String?> findRandomGoodie({required DateTime now}) async {
    return await firestore.cvRunTransaction((txn) async {
      return txnFindRandomGoodie(txn: txn, now: now);
    });
  }

  /// Finds a random goodie within a transaction.
  ///
  /// Returns the goodie ID if won, or null otherwise.
  Future<String?> txnFindRandomGoodie({
    required CvFirestoreTransaction txn,
    required DateTime now,
  }) async {
    var config = _lastGoodiesConfigUsed = await txn.refGet(_fsGoodiesConfigRef);

    if (config.exists) {
      var random = Random();
      var chance = random.nextDouble();
      var winningChance = config.winningChance.v ?? 0;
      if (chance < winningChance) {
        CvDocumentReference<FsGoodiesState> goodiesStateRef;
        if (config.isModeDaily) {
          var offset = TimeOffset.parse(config.startOfDayTimeOffset.v ?? '');
          var day = CalendarDay.fromTimestamp(
            now.subtract(Duration(milliseconds: offset.milliseconds)).toUtc(),
          );
          goodiesStateRef = _fsGoodiesDailyStateRef(day);
        } else if (config.isModeOnce) {
          goodiesStateRef = fsGoodiesStateRef;
        } else {
          throw UnsupportedError('Bad config: $config');
        }
        var state = await txn.refGet(goodiesStateRef);

        if (!state.exists) {
          state = FsGoodiesState()
            ..path = goodiesStateRef.path
            ..goodies.v = config.goodies.v
                ?.map(
                  (e) => CvGoodieState()
                    ..id.v = e.id.v
                    ..count.v = e.quantity.v,
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
