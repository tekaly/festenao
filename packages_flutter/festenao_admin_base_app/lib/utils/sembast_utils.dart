import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/sembast/projects_db.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Extension for [DbProject]
extension DbProjectUtils on DbProject {
  /// Update the [DbProject] from a [FsProject]
  void fromFirestore({
    required FsProject fsProject,

    /// Optional can be need after a create
    String? projectId,
    required TkCmsFsUserAccess? projectAccess,
    required String userId,
  }) {
    name.v = fsProject.name.v;
    uid.v = projectId ?? fsProject.id;
    this.userId.setValue(userId);
    if (projectAccess != null) {
      userAccessFields.fromCvFields(projectAccess.userAccessFields);
    }
  }

  /// Check if the [DbProject] need to be updated from another [DbProject]
  bool needUpdate(DbProject project) {
    return name.v != project.name.v ||
        uid.v != project.uid.v ||
        userId.v != project.userId.v ||
        admin.v != project.admin.v ||
        write.v != project.write.v ||
        read.v != project.read.v ||
        role.v != project.role.v;
  }
}
