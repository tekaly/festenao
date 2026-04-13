import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';
import 'package:festenao_common/firebase/firestore_database.dart';

/// Festenao user project sdb bloc
class FestenaoUserProjectSdbBloc extends AutoDisposeBaseBloc {
  /// Parent projects bloc
  final FestenaoUserProjectsSdbBloc projectsSdbBloc;

  /// Project ID
  final String projectId;

  // ignore: cancel_subscriptions
  StreamSubscription? _projectSubscription;
  late final _userProjectSubject = audiAddBehaviorSubject(
    BehaviorSubject<SdbUserProject?>(),
  );

  /// Project stream
  ValueStream<SdbUserProject?> get projectStream => _userProjectSubject.stream;

  Future<void> _syncProjectMeta(String userId) async {
    var synchronizer = UserProjectsSdbSynchronizer(
      projectsSdb: projectsSdbBloc.projectsSdb,
      fsProjects: projectsSdbBloc.fsProjectDb,
    );
    await synchronizer.syncOne(userId: userId, projectId: projectId);
  }

  /// Festenao user project sdb bloc
  FestenaoUserProjectSdbBloc({
    required this.projectsSdbBloc,
    required this.projectId,
  }) {
    cvAddConstructors([FsProject.new]);
    var projectsSdb = projectsSdbBloc.projectsSdb;
    audiAddStreamSubscription(
      projectsSdbBloc.firebaseUserStream.listen((user) {
        audiDispose(_projectSubscription);
        if (user != null) {
          _projectSubscription = audiAddStreamSubscription(
            projectsSdbBloc.projectsSdb
                .onProject(projectId, userId: user.uid)
                .listen((project) async {
                  if (project == null) {
                    // try to sync it first
                    await _syncProjectMeta(user.uid);
                    project = await projectsSdb.getProject(
                      projectId,
                      userId: user.uid,
                    );
                  }
                  _userProjectSubject.add(project);
                }),
          );
        } else {
          _userProjectSubject.add(null);
        }
      }),
    );
  }
}
