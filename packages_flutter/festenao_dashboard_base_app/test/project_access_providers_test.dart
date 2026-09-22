import 'package:festenao_dashboard_base_app/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A container with no identity, so nothing reaches firebase.
ProviderContainer _signedOutContainer() {
  var container = ProviderContainer(
    overrides: [rpdIdentityProvider.overrideWithValue(null)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('project access providers', () {
    test('signed out, the projects access state is empty', () async {
      var container = _signedOutContainer();
      // Kept alive the way a watching screen would, or it auto-disposes
      // before the stream has emitted anything.
      addTearDown(
        container.listen(rpdProjectsAccessProvider, (previous, next) {}).close,
      );
      var state = await container.read(rpdProjectsAccessProvider.future);
      expect(state.identity, isNull);
      expect(state.projects, isEmpty);
    });

    test('signed out, syncing the projects is a no-op', () async {
      var container = _signedOutContainer();
      // No identity means no firestore access list to rebuild from: it has to
      // return rather than reach for a user id that is not there.
      await container
          .read(rpdProjectsAccessProvider.notifier)
          .syncUserProjects();
    });

    test('signed out, an entity is neither found nor ready', () async {
      var container = _signedOutContainer();
      addTearDown(
        container
            .listen(rpdProjectAccessProvider('p1'), (previous, next) {})
            .close,
      );
      var state = await container.read(rpdProjectAccessProvider('p1').future);
      expect(state.project, isNull);
      expect(state.fsProject, isNull);
      expect(state.dbProjectReady, isFalse);
    });

    test('each entity has its own access notifier', () {
      var container = _signedOutContainer();
      expect(
        container.read(rpdProjectAccessProvider('p1').notifier).entityId,
        'p1',
      );
      expect(
        container.read(rpdProjectAccessProvider('p2').notifier).entityId,
        'p2',
      );
    });

    test('the mirror database is scoped, and null means firestore only', () {
      // What playelio and songbookelio override: their entity has no local
      // mirror, so the screens read it from firestore directly.
      var container = ProviderContainer(
        overrides: [
          rpdIdentityProvider.overrideWithValue(null),
          currentProjectsMirrorDbProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(currentProjectsMirrorDbProvider), isNull);
    });
  });
}
