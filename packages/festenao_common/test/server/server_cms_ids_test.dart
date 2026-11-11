import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// The ids of a cms url are document ids (level 12 review).
void main() {
  const app = 'festenao-dev';
  late FirebaseContext firebaseContext;
  late FestenaoServerApp server;

  setUpAll(() async {
    initFestenaoFsBuilders();
    firebaseContext = await initFirebaseServicesLocalMemory(
      projectId: 'server-cms-ids',
    ).init();
    server = FestenaoServerApp(
      app: app,
      context: TkCmsServerAppContext(
        firebaseContext: firebaseContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    var ref = const FestenaoCmsSiteRef(
      app: app,
      projectId: 'p1',
      dataId: 'content',
    );
    await CvDocumentReference<FsProject>(
      ref.projectDocumentPath,
    ).set(firebaseContext.firestore, FsProject()..name.v = 'My festival');
    await festenaoCmsAddProjectPages(
      firestore: firebaseContext.firestore,
      ref: ref,
      pages: [
        SdbCmsPage()
          ..title.v = 'About'
          ..body.v = 'Hello'
          ..published.v = true,
      ],
    );
  });

  tearDownAll(() async {
    await server.cmsContentCache.close();
    await firebaseContext.close();
  });

  Future<CmsResponse> get(String path) => server.handleCmsRequest(
    CmsSiteRequest.fromUrl(
      Uri.parse('https://my-app-dev.web.app/$path'),
      mountNames: server.cmsMountNames,
    ),
  );

  test('a site still served', () async {
    expect((await get('cms/p1/content/')).statusCode, 200);
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('an encoded slash in an id is not found', () async {
    for (var path in [
      'cms/p1%2Fx/content/',
      'cms/p1/content%2Fx/',
      'cms/p1%2Fdata%2Fcontent/x/',
      'cms/p1/%2E%2E/',
    ]) {
      var response = await get(path);
      expect(response.statusCode, 404, reason: '$path: ${response.body}');
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
