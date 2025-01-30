import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:tkcms_admin_app/firebase/database_service.dart';
import 'package:tkcms_admin_app/sembast/sembast.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_content.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

class _ContentDbInfo {
  int refCount = 1;
  final ContentDb contentDb;
  _ContentDbInfo({required this.contentDb});
}

class ProjectsDbBloc {
  ProjectsDbBloc({required this.app});
  final String app;

  final _lock = Lock();
  final _map = <String, _ContentDbInfo>{};
  Future<ContentDb> grabContentDb(
      {required String userId, required String projectId}) async {
    var contentDb =
        await grabContentDbOrNull(projectId: projectId, userId: userId);
    if (contentDb == null) {
      throw StateError('ContentDb not found for $projectId');
    }
    return contentDb;
  }

  String _key(String userId, String projectId) => '$userId/$projectId';
  Future<ContentDb?> grabContentDbOrNull(
      {required String userId, required String projectId}) async {
    var key = _key(userId, projectId);
    return await _lock.synchronized(() async {
      var info = _map[key];
      if (info != null) {
        info.refCount++;
        return info.contentDb;
      }

      await globalProjectsDb.ready;
      var dbProject =
          await globalProjectsDb.getProject(projectId, userId: userId);
      if (dbProject == null) {
        return null;
      }

      var contentDb = ContentDb(
          projectId: projectId,
          firestoreDatabaseContext: FirestoreDatabaseContext(
              firestore: gFsDatabaseService.firestore,
              rootDocument: gFsDatabaseService
                  .firestoreDatabaseContext.rootDocument!
                  .collection(fsProjectCollectionInfo.id)
                  .doc(projectId)),
          sembastDatabaseContext:
              globalSembastDatabasesContext.db('content.db'));
      await contentDb.ready;
      _map[projectId] = _ContentDbInfo(contentDb: contentDb);
      return contentDb;
    });
  }

  @protected
  Future<void> closeContentDb(String projectId) async {
    await _lock.synchronized(() {
      var info = _map[projectId];
      if (info != null) {
        info.contentDb.close();
        _map.remove(projectId);
      }
    });
  }

  Future<void> releaseContentDb(ContentDb contentDb) async {
    return await _lock.synchronized(() async {
      var info = _map[contentDb.projectId];
      if (info?.contentDb == contentDb) {
        var refCount = --info!.refCount;

        if (refCount == 0) {
          await contentDb.close();
          _map.remove(contentDb.projectId);
        }
      }
    });
    // Close the database
  }
}

late ProjectsDbBloc globalProjectsDbBloc;
