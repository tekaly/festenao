import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/booklets_db.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Extension for [DbBooklet]
extension DbBookletUtils on DbBooklet {
  /// Update the [DbBooklet] from a [FsBooklet]
  void fromFirestore(
      {required FsBooklet fsBooklet,
      required TkCmsFsUserAccess bookletAccess,
      required String userId}) {
    name.v = fsBooklet.name.v;
    uid.v = fsBooklet.id;
    this.userId.v = userId;
    userAccessFields.fromCvFields(bookletAccess.userAccessFields);
  }

  /// Check if the [DbBooklet] need to be updated from another [DbBooklet]
  bool needUpdate(DbBooklet booklet) {
    return name.v != booklet.name.v ||
        uid.v != booklet.uid.v ||
        userId.v != booklet.userId.v ||
        admin.v != booklet.admin.v ||
        write.v != booklet.write.v ||
        read.v != booklet.read.v ||
        role.v != booklet.role.v;
  }
}
