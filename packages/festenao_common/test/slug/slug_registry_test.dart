import 'package:festenao_common/festenao_slug.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  group('FestenaoSlugRegistry', () {
    late FestenaoSlugRegistry registry;
    setUp(() {
      registry = FestenaoSlugRegistry(
        firestore: newFirestoreMemory(),
        rootPath: 'app/test',
      );
    });
    test('claim and resolve', () async {
      expect(await registry.resolve('fest'), isNull);
      expect(await registry.isAvailable('fest'), isTrue);
      await registry.claim(slug: 'fest', entityType: 'event', entityId: 'e1');
      var doc = (await registry.resolve('fest'))!;
      expect(doc.slug, 'fest');
      expect(doc.entityId.v, 'e1');
      expect(doc.entityType.v, 'event');
      expect(doc.alias.v, isFalse);
      expect(await registry.isAvailable('fest'), isFalse);
      expect(
        await registry.isAvailable('fest', entityType: 'event', entityId: 'e1'),
        isTrue,
      );
      // Claiming it again for the same entity is fine.
      await registry.claim(slug: 'fest', entityType: 'event', entityId: 'e1');
      // Not for another one.
      await expectLater(
        registry.claim(slug: 'fest', entityType: 'event', entityId: 'e2'),
        throwsA(isA<FestenaoSlugTakenException>()),
      );
      await expectLater(
        registry.claim(slug: 'Fest', entityType: 'event', entityId: 'e2'),
        throwsA(isA<FestenaoSlugInvalidException>()),
      );
      expect(await registry.resolve('Not valid'), isNull);
    });
    test('move keeps an alias', () async {
      await registry.claim(slug: 'fest', entityType: 'event', entityId: 'e1');
      await registry.claim(
        slug: 'fest-2025',
        entityType: 'event',
        entityId: 'e1',
        previousSlug: 'fest',
      );
      expect((await registry.resolve('fest'))!.alias.v, isTrue);
      expect((await registry.resolve('fest'))!.entityId.v, 'e1');
      expect((await registry.resolve('fest-2025'))!.alias.v, isFalse);
      expect(
        (await registry.slugsOf('event', 'e1')).map((doc) => doc.slug).toSet(),
        {'fest', 'fest-2025'},
      );
      // Back to the alias: it becomes the current one again.
      await registry.claim(
        slug: 'fest',
        entityType: 'event',
        entityId: 'e1',
        previousSlug: 'fest-2025',
        keepAlias: false,
      );
      expect((await registry.resolve('fest'))!.alias.v, isFalse);
      expect(await registry.resolve('fest-2025'), isNull);
    });
    test('claimFromText and release', () async {
      expect(
        await registry.claimFromText(
          'Fest',
          entityType: 'event',
          entityId: 'e1',
        ),
        'fest',
      );
      expect(
        await registry.claimFromText(
          'Fest!',
          entityType: 'event',
          entityId: 'e2',
        ),
        'fest-2',
      );
      await registry.release('fest', entityType: 'event', entityId: 'e2');
      expect(await registry.resolve('fest'), isNotNull);
      await registry.release('fest', entityType: 'event', entityId: 'e1');
      expect(await registry.resolve('fest'), isNull);
      await registry.releaseAll('event', 'e2');
      expect(await registry.resolve('fest-2'), isNull);
    });
  });
}
