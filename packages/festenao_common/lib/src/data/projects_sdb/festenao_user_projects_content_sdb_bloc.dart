import 'dart:async';

import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

import '../../../auth/festenao_auth.dart';

/// Festenao project sdb helper
class FestenaoUserProjectsSdbBloc extends AutoDisposeBaseBloc {
  /// Firestore project service
  final TkCmsFirestoreDatabaseServiceEntityAccess<FsProject> fsProjectDb;

  /// Projects database
  final UserProjectsSdb projectsSdb;

  /// Firebase user stream
  Stream<FirebaseUser?> firebaseUserStream;

  /// Festenao project sdb helper
  FestenaoUserProjectsSdbBloc({
    required this.fsProjectDb,
    required this.projectsSdb,
    required this.firebaseUserStream,
  });
}
