import 'package:festenao_common/festenao_slug.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  late FestenaoFirestoreDatabase db;
  setUp(() async {
    var firebaseContext = (await initFirebaseServicesMemory()).initContext();
    db = FestenaoFirestoreDatabase(
      firebaseContext: firebaseContext,
      flavorContext: AppFlavorContext.test,
    );
  });

  Future<FsProject> getProject(String projectId) =>
      db.projectDb.fsEntityRef(projectId).get(db.firestore);

  Future<String> createProject(String name) => db.projectDb.createEntity(
    userId: 'u1',
    entity: FsProject()..name.v = name,
  );

  test('project slugs', () async {
    var projectId = await createProject('Blog');
    expect(await db.resolveProjectSlug('blog'), isNull);
    await db.setProjectSlug(projectId, 'blog');
    expect(await db.resolveProjectSlug('blog'), projectId);
    var project = await getProject(projectId);
    expect(project.slug.v, 'blog');
    expect(project.slugs.v, ['blog']);
    expect(project.name.v, 'Blog');

    await db.setProjectSlug(projectId, 'my-blog');
    expect(await db.resolveProjectSlug('blog'), projectId);
    expect((await db.slugRegistry().resolve('blog'))!.alias.v, isTrue);
    expect(await db.resolveProjectSlug('my-blog'), projectId);
    expect((await getProject(projectId)).urlSlugs, ['my-blog', 'blog']);

    var otherId = await createProject('Other');
    await expectLater(
      db.setProjectSlug(otherId, 'my-blog'),
      throwsA(isA<FestenaoSlugTakenException>()),
    );
    await db.releaseProjectSlug(projectId);
    expect(await db.resolveProjectSlug('my-blog'), isNull);
    // The previous one, in the project slugs, is released too.
    expect(await db.resolveProjectSlug('blog'), isNull);
    // Not a project.
    await db.slugRegistry().claim(
      slug: 'an-event',
      entityType: 'event',
      entityId: 'e1',
    );
    expect(await db.resolveProjectSlug('an-event'), isNull);
  });

  test('several slugs for one project', () async {
    var projectId = await createProject('Trad hiv');
    // The first one becomes the current one.
    await db.addProjectSlug(projectId, 'tradhiv');
    await db.addProjectSlug(projectId, 'tradhiv2027');
    var project = await getProject(projectId);
    expect(project.slug.v, 'tradhiv');
    expect(project.urlSlugs, ['tradhiv', 'tradhiv2027']);
    expect(project.urlSegment, 'tradhiv');
    expect(await db.resolveProjectSlug('tradhiv2027'), projectId);
    var registry = db.slugRegistry();
    expect((await registry.resolve('tradhiv'))!.alias.v, isFalse);
    expect((await registry.resolve('tradhiv2027'))!.alias.v, isTrue);
    // Added again: nothing changes.
    await db.addProjectSlug(projectId, 'tradhiv');
    expect((await getProject(projectId)).urlSlugs, ['tradhiv', 'tradhiv2027']);

    // The extra one becomes the current one.
    await db.setProjectSlug(projectId, 'tradhiv2027');
    project = await getProject(projectId);
    expect(project.urlSlugs, ['tradhiv2027', 'tradhiv']);
    expect((await registry.resolve('tradhiv'))!.alias.v, isTrue);
    expect((await registry.resolve('tradhiv2027'))!.alias.v, isFalse);

    // Removing the current one: the next one takes its place.
    await db.removeProjectSlug(projectId, 'tradhiv2027');
    project = await getProject(projectId);
    expect(project.urlSlugs, ['tradhiv']);
    expect(await db.resolveProjectSlug('tradhiv2027'), isNull);
    expect((await registry.resolve('tradhiv'))!.alias.v, isFalse);

    // Removing the last one: back to the project id.
    await db.removeProjectSlug(projectId, 'tradhiv');
    project = await getProject(projectId);
    expect(project.slug.v, isNull);
    expect(project.urlSlugs, isEmpty);
    expect(project.urlSegment, projectId);
    expect(await registry.list(), isEmpty);

    // Another project's slug is not removed.
    var otherId = await createProject('Other');
    await db.addProjectSlug(otherId, 'other');
    await db.removeProjectSlug(projectId, 'other');
    expect(await db.resolveProjectSlug('other'), otherId);
  });

  test('a slug moved to another project', () async {
    var registry = db.slugRegistry();
    var firstId = await createProject('Fest 2026');
    var nextId = await createProject('Fest 2027');
    // Nobody has it: as setProjectSlug.
    await db.moveProjectSlug('fest', firstId);
    expect(await db.resolveProjectSlug('fest'), firstId);
    expect((await getProject(firstId)).urlSlugs, ['fest']);
    // Its own already: nothing changes.
    await db.moveProjectSlug('fest', firstId);
    expect((await getProject(firstId)).urlSlugs, ['fest']);

    // Taken from the first project, which had it alone: back to its id.
    await db.setProjectSlug(nextId, 'fest-2027');
    await db.moveProjectSlug('fest', nextId);
    expect(await db.resolveProjectSlug('fest'), nextId);
    var first = await getProject(firstId);
    expect(first.slug.v, isNull);
    expect(first.urlSlugs, isEmpty);
    expect(first.urlSegment, firstId);
    // The previous slug of the next one: an alias, its links keep working.
    var next = await getProject(nextId);
    expect(next.slug.v, 'fest');
    expect(next.urlSlugs, ['fest', 'fest-2027']);
    expect((await registry.resolve('fest'))!.alias.v, isFalse);
    expect((await registry.resolve('fest-2027'))!.alias.v, isTrue);
    expect(await db.resolveProjectSlug('fest-2027'), nextId);

    // Taken from a project with another slug: that one becomes its
    // current one.
    await db.setProjectSlug(firstId, 'fest-2026');
    await db.moveProjectSlug('fest', firstId);
    await db.moveProjectSlug('fest', nextId);
    first = await getProject(firstId);
    expect(first.slug.v, 'fest-2026');
    expect(first.urlSlugs, ['fest-2026']);
    expect((await registry.resolve('fest-2026'))!.alias.v, isFalse);
    expect(await db.resolveProjectSlug('fest-2026'), firstId);
    expect(await db.resolveProjectSlug('fest'), nextId);
    // An alias taken: the current slug of its project stays.
    await db.moveProjectSlug('fest-2027', firstId);
    next = await getProject(nextId);
    expect(next.slug.v, 'fest');
    expect(next.urlSlugs, ['fest']);
    first = await getProject(firstId);
    expect(first.urlSlugs, ['fest-2027', 'fest-2026']);
    expect((await registry.list()).map((slug) => slug.slug).toList()..sort(), [
      'fest',
      'fest-2026',
      'fest-2027',
    ]);

    // Not a project's, not valid, no such project.
    await registry.claim(slug: 'an-event', entityType: 'event', entityId: 'e1');
    await expectLater(
      db.moveProjectSlug('an-event', firstId),
      throwsA(isA<FestenaoSlugTakenException>()),
    );
    await expectLater(
      db.moveProjectSlug('Not Valid', firstId),
      throwsA(isA<FestenaoSlugInvalidException>()),
    );
    await expectLater(db.moveProjectSlug('fest', 'missing'), throwsStateError);
    expect(await db.resolveProjectSlug('fest'), nextId);
  });

  test('resolveProjectUrlSegment', () async {
    var projectId = await createProject('Blog');
    await db.setProjectSlug(projectId, 'blog');
    expect(await db.resolveProjectUrlSegment('blog'), projectId);
    expect(await db.resolveProjectUrlSegment('Blog'), projectId);
    // A project without a slug opens at its id.
    var otherId = await createProject('Other');
    expect(await db.resolveProjectUrlSegment(otherId), otherId);
    expect(await db.resolveProjectUrlSegment('nothing-here'), isNull);
    expect(await db.resolveProjectUrlSegment('..'), isNull);
  });

  test('slug right', () async {
    expect(await db.canSetSlug('u1'), isFalse);
    var ref = db.appUserAccessRef('u1');
    await ref.set(db.firestore, TkCmsFsUserAccess()..read.v = true);
    expect(await db.canSetSlug('u1'), isFalse);
    await ref.set(
      db.firestore,
      TkCmsFsUserAccess()
        ..read.v = true
        ..setSlugRole(true),
    );
    expect(await db.canSetSlug('u1'), isTrue);
    expect(ref.path, 'access/app/entity_id/${db.app}/user_access/u1');
    await ref.set(db.firestore, TkCmsFsUserAccess.admin());
    expect(await db.canSetSlug('u1'), isTrue);
  });

  test('setSlugRole keeps the other roles', () {
    var access = TkCmsFsUserAccess()..role.v = 'user';
    access.setSlugRole(true);
    expect(access.role.v, 'user,slug');
    expect(access.canSetSlug, isFalse); // Not a document read from firestore.
    access.setSlugRole(true);
    expect(access.role.v, 'user,slug');
    access.setSlugRole(false);
    expect(access.role.v, 'user');
    access.setSlugRole(false);
    expect(access.role.v, 'user');
    access.role.v = 'slug';
    access.setSlugRole(false);
    expect(access.role.v, isNull);
  });
}
