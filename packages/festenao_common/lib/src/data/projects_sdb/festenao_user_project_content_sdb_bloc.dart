import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';

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

  /// Festenao user project sdb bloc
  FestenaoUserProjectSdbBloc({
    required this.projectsSdbBloc,
    required this.projectId,
  }) {
    audiAddStreamSubscription(
      projectsSdbBloc.firebaseUserStream.listen((user) {
        audiDispose(_projectSubscription);
        if (user != null) {
          _projectSubscription = audiAddStreamSubscription(
            projectsSdbBloc.projectsSdb
                .onProject(projectId, userId: user.uid)
                .listen((project) {
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
