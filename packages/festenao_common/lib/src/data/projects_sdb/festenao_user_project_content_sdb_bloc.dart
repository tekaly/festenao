import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:festenao_common/data/src/import.dart';
import 'package:festenao_common/festenao_audi.dart';

/// Festenao user project sdb bloc
class FestenaoUserProjectContentSdbBloc extends AutoDisposeBaseBloc {
  /// Parent projects bloc
  final FestenaoUserProjectSdbBloc projectSdbBloc;

  /// Open options
  final SdbOpenDatabaseOptions contentSdbOptions;

  /// Data id, we can multiple synced database in one project
  final String dataId;
  // in app/<appId>project/<projectId>/data/<dataId>

  // ignore: cancel_subscriptions

  /// Festenao user project sdb bloc
  FestenaoUserProjectContentSdbBloc({
    required this.projectSdbBloc,
    required this.contentSdbOptions,
    required this.dataId,
  });
}
