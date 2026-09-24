import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:tkcms_common/tkcms_audi.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// Projects screen bloc state
class ProjectSdbEditScreenBlocState {
  final TkCmsFbIdentity? identity;

  /// User
  FirebaseUser? get user => identity?.user;

  /// Projects
  final SdbUserProject? project;

  /// The current slug of the project url (`/p/<slug>`), null when none.
  final String? slug;

  /// Projects screen bloc state
  ProjectSdbEditScreenBlocState({this.project, this.identity, this.slug});
}

/// Projects screen bloc
class ProjectEditScreenBloc
    extends AutoDisposeStateBaseBloc<ProjectSdbEditScreenBlocState> {
  final SdbUserProject? project; // null for creation

  String get projectId => project!.id;
  bool get isCreate => project == null;

  TkCmsFbIdentity? firebaseIdentity;

  /// Projects screen bloc
  ProjectEditScreenBloc({this.project}) {
    () async {
      var identity = firebaseIdentity =
          ((await globalTkCmsFbIdentityBloc.state.first).identity);
      if (identity == null) {
        add(ProjectSdbEditScreenBlocState());
      } else {
        String? slug;
        var project = this.project;
        if (project != null) {
          try {
            var fsDb = globalFestenaoFirestoreDatabase;
            slug =
                (await fsDb.projectDb
                        .fsEntityRef(project.fsId)
                        .get(fsDb.firestore))
                    .slug
                    .v;
          } catch (_) {
            // Offline, or not readable: edited without its url.
          }
        }
        add(
          ProjectSdbEditScreenBlocState(
            project: project,
            identity: identity,
            slug: slug,
          ),
        );
      }
    }();
  }

  /// Save [project], and give it the url [slug] when it is a new one (see
  /// [FestenaoFirestoreDatabaseSlugExt.setProjectSlug]).
  Future<void> saveProject(
    SdbUserProject project, {
    String? slug,
    String? currentSlug,
  }) async {
    await globalProjectsSdb.ready;
    var fsDb = globalFestenaoFirestoreDatabase;
    var firestore = fsDb.firestore;
    if (isCreate) {
      var fsProject = FsProject()..name.setValue(project.name.v);
      var identity = firebaseIdentity;
      var userId = identity?.userId;

      var projectUid = await fsDb.projectDb.createEntity(
        userId: userId,
        entity: fsProject,
        entityId: project.uid.v,
      );
      if (slug != null && slug.isNotEmpty) {
        await fsDb.setProjectSlug(projectUid, slug);
      }
      if (userId == null) {
        var newDbProject = SdbUserProject()
          ..fromFirestore(
            fsProject: fsProject,
            projectId: projectUid,
            projectAccess: TkCmsFsUserAccess.admin(),
            userId: identity!.userLocalId!,
          );
        await globalProjectsSdb.addProject(newDbProject);
      } else {
        var userProjectAccess = await fsDb.projectDb
            .fsUserEntityAccessRef(userId, projectUid)
            .get(firestore);
        var newDbProject = SdbUserProject()
          ..fromFirestore(
            fsProject: fsProject,
            projectId: projectUid,
            projectAccess: userProjectAccess,
            userId: userId,
          );
        await globalProjectsSdb.addProject(newDbProject);
      }
    } else {
      await firestore.cvRunTransaction((txn) async {
        var fsProjectRef = fsDb.projectDb.fsEntityRef(project.fsId);

        var fsProject = await txn.refGet(fsProjectRef);
        if (!fsProject.exists) {
          throw UnsupportedError('project not found');
        }
        fsProject.name.setValue(project.name.v);
        txn.refUpdate(fsProjectRef, fsProject);
      });
      if (slug != null && slug.isNotEmpty && slug != currentSlug) {
        await fsDb.setProjectSlug(project.fsId, slug);
      }
      await globalProjectsSdb.db.inStoreTransaction(
        dbProjectStore.rawRef,
        SdbTransactionMode.readWrite,
        (txn) async {
          var dbProject = await dbProjectStore.record(projectId).get(txn);
          if (dbProject == null) {
            throw UnsupportedError('Local project not found');
          }
          dbProject.name.v = project.name.v;
          await dbProjectStore.record(projectId).put(txn, dbProject);
        },
      );
    }
  }
}
