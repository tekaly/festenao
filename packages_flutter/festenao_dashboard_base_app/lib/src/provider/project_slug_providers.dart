import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_slug.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'project_access_providers.dart';

/// The current slug of the entity [entityId] of the scoped entity access
/// ([currentEntityAccessProvider]), live; null when it has none, or when the
/// entity is not a project (only the projects have an url, `/p/<slug>`).
///
/// Read from the entity document (its `slug` copy, see
/// [FestenaoFirestoreDatabaseSlugExt.setProjectSlug]) whatever its model.
final dashboardEntitySlugProvider = StreamProvider.autoDispose
    .family<String?, String>((ref, entityId) {
      var fsDb = ref.watch(currentEntityAccessProvider);
      if (fsDb.entityCollectionInfo.id != festenaoProjectSlugEntityType) {
        return Stream.value(null);
      }
      return fsDb.firestore
          .doc(fsDb.fsEntityRef(entityId).path)
          .onSnapshotSupport()
          .map(
            (snapshot) =>
                snapshot.exists ? snapshot.data['slug'] as String? : null,
          );
    }, name: 'dashboardEntitySlug');
