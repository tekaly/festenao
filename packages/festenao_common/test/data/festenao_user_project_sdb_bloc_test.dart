import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/firebase/firebase_sim_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';

void main() {
  group('FestenaoUserProjectSdbBloc', () {
    late UserProjectsSdb projectsSdb;
    late FestenaoUserProjectsSdbBloc projectsSdbBloc;
    final userId = 'test_user';
    final projectId = 'test_project';
    late Firestore firestore;

    setUp(() async {
      var firebaseApp = newFirebaseAppLocal(localPath: 'test');
      firestore = newFirestoreServiceMemory().firestore(firebaseApp);
      projectsSdb = UserProjectsSdb.inMemory();

      // Initialize the user in the DB so onProjectsUserReady works
      await projectsSdb.setCurrentIdentityId(userId);

      var firestoreDatabaseContext = FirestoreDatabaseContext(
        firestore: firestore,
        rootDocumentPath: 'app/test',
      );
      projectsSdbBloc = FestenaoUserProjectsSdbBloc(
        appFlavorContext: AppFlavorContext(
          flavorContext: FlavorContext.dev,
          app: 'test',
        ),
        fsProjectDb: TkCmsFirestoreDatabaseServiceEntityAccess(
          entityCollectionInfo: projectCollectionInfo,
          firestoreDatabaseContext: firestoreDatabaseContext,
          firestore: firestore,
        ),
        projectsSdb: projectsSdb,
        firebaseUserStream: BehaviorSubject<FirebaseUser?>.seeded(
          StubFirebaseUser(uid: userId),
        ),
      );
    });

    tearDown(() async {
      await projectsSdb.close();
      await firestore.app.delete();
    });

    test('projectStream', () async {
      var bloc = FestenaoUserProjectSdbBloc(
        projectsSdbBloc: projectsSdbBloc,
        projectId: projectId,
      );

      // Initially null
      expect(await bloc.projectStream.first, isNull);

      // Add a project to the DB
      var project = SdbUserProject()
        ..uid.v = projectId
        ..userId.v = userId
        ..name.v = 'Test Project';

      await projectsSdb.ready;
      await dbProjectStore.add(projectsSdb.db, project);

      // Wait for the stream to emit the new project
      var updatedProject = await bloc.projectStream
          .where((p) => p != null)
          .first;
      expect(updatedProject!.name.v, 'Test Project');
      expect(updatedProject.uid.v, projectId);

      bloc.dispose();
    });

    test('fromServer', () async {
      var project = FsProject()..name.v = 'Test Project';
      var projectId = await projectsSdbBloc.fsProjectDb.createEntity(
        userId: userId,
        entity: project,
      );
      var bloc = FestenaoUserProjectSdbBloc(
        projectsSdbBloc: projectsSdbBloc,
        projectId: projectId,
      );

      // Initially null
      expect(await bloc.projectStream.first, isNotNull);
    });
  });
}

class StubFirebaseUser implements FirebaseUser {
  @override
  final String uid;
  StubFirebaseUser({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
