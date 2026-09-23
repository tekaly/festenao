import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festenao_server_cms.dart';

import 'demo_cms_data.dart';

/// Project id of the demo cms site in firestore.
const demoCmsProjectId = 'demo_festival';

/// Data id of the synced content of the demo project.
const demoCmsDataId = 'content';

/// Creates the demo project of [app] in [firestore]: its document, named
/// after the demo site, and [demoCmsPages] as the synced content
/// `app/<app>/project/<projectId>/data/<dataId>`, what the cms function of a
/// `FestenaoServerApp` serves at `<cms>/<projectId>/<dataId>/`.
///
/// For an in memory firestore (a local server, a test): the project gets no
/// access rights.
Future<FestenaoCmsSiteRef> fillDemoCmsProject({
  required Firestore firestore,
  required String app,
  String projectId = demoCmsProjectId,
  String dataId = demoCmsDataId,
}) async {
  initFestenaoFsBuilders();
  var ref = FestenaoCmsSiteRef(app: app, projectId: projectId, dataId: dataId);
  await CvDocumentReference<FsProject>(ref.projectDocumentPath).set(
    firestore,
    FsProject()
      ..name.v = demoCmsSiteName
      ..created.v = Timestamp.now()
      ..active.v = true,
  );
  await festenaoCmsAddProjectPages(
    firestore: firestore,
    ref: ref,
    pages: demoCmsPages(),
  );
  return ref;
}
