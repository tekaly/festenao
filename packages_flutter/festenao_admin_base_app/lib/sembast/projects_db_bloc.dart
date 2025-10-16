import 'package:festenao_admin_base_app/firebase/firestore_database.dart';
import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:flutter/foundation.dart';
import 'package:tkcms_admin_app/firebase/database_service.dart';
import 'package:tkcms_admin_app/sembast/sembast.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_content.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

class _ContentDbInfo implements GrabbedContentDb {
  final String key;
  int refCount = 1;
  @override
  final ContentDb contentDb;
  _ContentDbInfo({required this.key, required this.contentDb});

  Future<void> close() async {
    await contentDb.close();
  }
}

abstract class GrabbedContentDb {
  ContentDb get contentDb;
}

/// Compat
typedef SingleProjectDbBloc = SingleCompatProjectDbBloc;

/// Compat
abstract class SingleCompatProjectDbBloc implements ProjectsDbBloc {
  String get projectId;
  SyncedDb get syncedDb;
  factory SingleCompatProjectDbBloc({
    required SyncedDb syncedDb,
    required String projectPath,
  }) => _SingleProjectDbBloc(syncedDb: syncedDb, projectPath: projectPath);
}

class _SingleProjectDbBloc implements SingleCompatProjectDbBloc {
  @override
  late final projectId = url.split(projectPath).last;
  final String projectPath;
  @override
  final SyncedDb syncedDb;

  _SingleProjectDbBloc({required this.syncedDb, required this.projectPath});
}

/// Enforced single app projectId
abstract class EnforcedSingleProjectDbBloc extends MultiProjectsDbBloc {
  String get enforcedProjectId;
  factory EnforcedSingleProjectDbBloc({
    required String app,
    required String projectId,
  }) => _EnforcedProjectsDbBloc(app: app, enforcedProjectId: projectId);
}

/// Multi projects db bloc
abstract class MultiProjectsDbBloc implements ProjectsDbBloc {
  Future<GrabbedContentDb> grabContentDb({
    required String userId,
    required String projectId,
  });
  Future<GrabbedContentDb?> grabContentDbOrNull({
    required String userId,
    required String projectId,
  });
  Future<void> releaseContentDb(GrabbedContentDb contentDb);

  factory MultiProjectsDbBloc({required String app}) =>
      _ProjectsDbBloc(app: app);
}

/// Projects db bloc
class ProjectsDbBloc {}

class _EnforcedProjectsDbBloc extends _ProjectsDbBloc
    implements EnforcedSingleProjectDbBloc {
  @override
  final String enforcedProjectId;

  _EnforcedProjectsDbBloc({
    required super.app,
    required this.enforcedProjectId,
  });
}

//class SingleProjectDbBloc extends _ProjectsDbBloc {}

class _ProjectsDbBloc implements MultiProjectsDbBloc {
  _ProjectsDbBloc({required this.app});
  final String app;

  final _lock = Lock();
  final _map = <String, _ContentDbInfo>{};
  @override
  Future<GrabbedContentDb> grabContentDb({
    required String userId,
    required String projectId,
  }) async {
    var contentDb = await grabContentDbOrNull(
      projectId: projectId,
      userId: userId,
    );
    if (contentDb == null) {
      throw StateError('ContentDb not found for $projectId');
    }
    return contentDb;
  }

  String _key(String userId, String projectId) => '$userId/$projectId';
  @override
  Future<GrabbedContentDb?> grabContentDbOrNull({
    required String userId,
    required String projectId,
  }) async {
    var key = _key(userId, projectId);
    return await _lock.synchronized(() async {
      var info = _map[key];
      if (info != null) {
        info.refCount++;
        return info;
      }

      await globalProjectsDb.ready;
      var dbProject = await globalProjectsDb.getProject(
        projectId,
        userId: userId,
      );
      if (dbProject == null) {
        return null;
      }

      var rootDocument = globalFestenaoFirestoreDatabase.projectDb.fsEntityRef(
        projectId,
      );

      if (kDebugMode) {
        print('Opening content db for $key at $rootDocument');
      }

      String encodeForPath(String input) {
        final encoded = base64Url.encode(utf8.encode(input));
        return encoded.replaceAll('=', ''); // remove padding for prettier names
      }

      var contentDb = ContentDb(
        projectId: projectId,
        firestoreDatabaseContext: FirestoreDatabaseContext(
          firestore: gFsDatabaseService.firestore,
          rootDocument: rootDocument,
        ),
        sembastDatabaseContext: globalSembastDatabasesContext.db(
          'content-${encodeForPath(projectId)}.db',
        ),
      );
      await contentDb.ready;
      info = _map[key] = _ContentDbInfo(key: key, contentDb: contentDb);
      return info;
    });
  }

  @override
  Future<void> releaseContentDb(GrabbedContentDb contentDb) async {
    return await _lock.synchronized(() async {
      var info = contentDb as _ContentDbInfo;

      var refCount = --info.refCount;

      if (refCount == 0) {
        await info.close();
        _map.remove(info.key);
      }
    });
    // Close the database
  }
}

/// Global projects db bloc
ProjectsDbBloc get globalProjectsDbBloc => globalProjectsDbBlocOrNull!;
set globalProjectsDbBloc(ProjectsDbBloc bloc) {
  globalProjectsDbBlocOrNull = bloc;
}

ProjectsDbBloc? globalProjectsDbBlocOrNull;
