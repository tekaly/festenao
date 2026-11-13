import 'dart:async';

import 'package:festenao_common/data/festenao_projects_fs.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// The contents of a project (the synchronized databases of the dashboard):
/// their `ready` never hangs, and they synchronize with the Firestore and
/// storage of their cache, not with those of the latest Firebase app.
void main() {
  late FirebaseContext firebaseContext;
  late UserProjectsSdb projectsSdb;

  setUpAll(() async {
    firebaseContext = (await initFirebaseServicesMemory()).initContext();
    // The latest app (`FirebaseApp.instance`) has neither Firestore nor
    // storage: only what the caches are given works.
    firebaseContext.firebase.initializeApp(name: 'bare');
    globalFestenaoUserProjectsFsBloc = FestenaoUserProjectsFsBloc(
      fs: newFileSystemMemory(),
    );
    projectsSdb = UserProjectsSdb(
      name: 'projects',
      factory: newSdbFactoryMemory(),
    );
  });

  SdbProjectsContentCache newCache() => SdbProjectsContentCache(
    projectsSdb: projectsSdb,
    app: 'test',
    firestore: firebaseContext.firestore,
    firebaseStorage: firebaseContext.storage,
  );

  SdbUserProject newProject(String? uid) => SdbUserProject()
    ..uid.v = uid
    ..userId.v = 'user1'
    ..name.v = 'Project';

  test('the content opens on the Firestore of its cache', () async {
    var content = SdbProjectContent(
      cache: newCache(),
      project: newProject('project1'),
      dataId: SdbProjectContent.defaultDataId,
      fs: newFileSystemMemory(),
    );
    await content.ready.timeout(const Duration(seconds: 10));
    expect(await content.contentSdb.onArtists().first, isEmpty);
    content.dispose();
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a content failing to open: ready fails', () async {
    // No project uid: the synced database cannot be named.
    var content = SdbProjectContent(
      cache: newCache(),
      project: newProject(null),
      dataId: SdbProjectContent.defaultDataId,
      fs: newFileSystemMemory(),
    );
    await expectLater(
      content.ready.timeout(const Duration(seconds: 10)),
      throwsA(isNot(isA<TimeoutException>())),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('a blog failing to open: ready fails', () async {
    var blog = SdbProjectContentBlog(
      cache: SdbProjectsContentBlogCache(
        firebaseContext.firestore,
        userProjectsSdb: projectsSdb,
        appFlavorContext: AppFlavorContext.test,
      ),
      project: newProject(null),
      dataId: 'blog',
      appFlavorContext: AppFlavorContext.test,
    );
    await expectLater(
      blog.ready.timeout(const Duration(seconds: 10)),
      throwsA(isNot(isA<TimeoutException>())),
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
