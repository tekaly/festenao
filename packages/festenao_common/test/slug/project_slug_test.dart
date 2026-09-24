import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  test('project slugs', () async {
    var firebaseContext = (await initFirebaseServicesMemory()).initContext();
    var db = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: AppFlavorContext.test,
    );
    var projectId = await db.projectDb.createEntity(
      userId: 'u1',
      entity: FsProject()..name.v = 'Blog',
    );
    expect(await db.resolveProjectSlug('blog'), isNull);
    await db.setProjectSlug(projectId, 'blog');
    expect(await db.resolveProjectSlug('blog'), projectId);
    var project = await db.projectDb.fsEntityRef(projectId).get(db.firestore);
    expect(project.slug.v, 'blog');
    expect(project.name.v, 'Blog');

    await db.setProjectSlug(projectId, 'my-blog');
    expect(await db.resolveProjectSlug('blog'), projectId);
    expect((await db.slugRegistry().resolve('blog'))!.alias.v, isTrue);
    expect(await db.resolveProjectSlug('my-blog'), projectId);

    var otherId = await db.projectDb.createEntity(
      userId: 'u2',
      entity: FsProject()..name.v = 'Other',
    );
    await expectLater(
      db.setProjectSlug(otherId, 'my-blog'),
      throwsA(isA<FestenaoSlugTakenException>()),
    );
    await db.releaseProjectSlug(projectId);
    expect(await db.resolveProjectSlug('my-blog'), isNull);
    // Not a project.
    await db.slugRegistry().claim(
      slug: 'an-event',
      entityType: 'event',
      entityId: 'e1',
    );
    expect(await db.resolveProjectSlug('an-event'), isNull);
  });
}
