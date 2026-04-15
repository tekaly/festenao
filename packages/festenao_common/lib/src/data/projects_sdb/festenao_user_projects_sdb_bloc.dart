import 'dart:async';

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

import '../../../auth/festenao_auth.dart';

/// Global user projects sdb
late final FestenaoUserProjectsSdbBloc globalFestenaoUserProjectsSdbBloc;

/// Festenao project sdb helper
class FestenaoUserProjectsSdbBloc extends AutoDisposeBaseBloc {
  /// Firestore project service
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjectDb;

  /// Projects database
  final UserProjectsSdb projectsSdb;

  /// App flavor context
  final AppFlavorContext appFlavorContext;

  /// Firebase user stream
  //Stream<FirebaseUser?> firebaseUserStream;

  late final _firebaseUserSubject = audiAddBehaviorSubject(
    BehaviorSubject<FirebaseUser?>(),
  );

  /// Festenao project sdb helper
  FestenaoUserProjectsSdbBloc({
    required this.fsProjectDb,
    required this.projectsSdb,
    required this.appFlavorContext,
    required Stream<FirebaseUser?> firebaseUserStream,
  }) {
    () async {
      await for (var user in firebaseUserStream) {
        _firebaseUserSubject.add(user);
      }
    }();
  }

  /// Firebase user stream
  ValueStream<FirebaseUser?> get firebaseUserStream =>
      _firebaseUserSubject.stream;
}
