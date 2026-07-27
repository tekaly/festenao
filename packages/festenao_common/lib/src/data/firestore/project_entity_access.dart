import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_firestore_v2.dart';

/// Common interface for project entities

/// Common interface for all entities
extension FestenaoFirestoreDatabaseServiceProjectAccessStandaloneExt<
  TFsEntity extends TkCmsFsProject
>
    on TkCmsFirestoreDatabaseServiceEntityAccess<TFsEntity> {
  /// Create entity.
  Future<String> standaloneCreateEntity({
    required TFsEntity entity,
    required String userId,
    String? entityId,
    String Function()? customIdGenerator,
  }) async {
    entity.created.v ??= Timestamp.now();
    entity.active.v ??= true;
    // Set the creator!
    entity.creatorUserId.v ??= userId;
    late String newEntityId;
    if (firestore.supportsTransaction) {
      newEntityId = await firestore.cvRunTransaction((txn) async {
        if (entityId != null) {
          newEntityId = entityId;
          var entityRef = fsEntityRef(newEntityId);
          var entitySnapshot = await txn.refGet(entityRef);
          if (entitySnapshot.exists) {
            throw StateError('Entity $newEntityId already exists');
          }
        } else {
          // Find a unique id
          newEntityId = await fsEntityCollectionRef
              .raw(firestore)
              .txnGenerateUniqueId(txn, customGenerator: customIdGenerator);
        }

        var entityRef = fsEntityRef(newEntityId);

        txn.refSet(entityRef, entity);
        return newEntityId;
      });
    } else {
      if (entityId != null) {
        newEntityId = entityId;
        var entityRef = fsEntityRef(newEntityId);
        var entitySnapshot = await firestore.refGet(entityRef);
        if (entitySnapshot.exists) {
          throw StateError('Entity $newEntityId already exists');
        }
      } else {
        // Find a unique id
        newEntityId = await fsEntityCollectionRef
            .raw(firestore)
            .noTxnGenerateUniqueId(customGenerator: customIdGenerator);
      }

      var entityRef = fsEntityRef(newEntityId);
      // Create the entity
      await firestore.refSet(entityRef, entity);
    }

    // Set access
    var entityUserAccess = TkCmsFsUserAccess()
      ..admin.v = true
      ..fixAccess();

    if (firestore.supportsTransaction) {
      await noTxnSetEntityUserAccess(
        entityId: newEntityId,
        userId: userId,
        userAccess: entityUserAccess,
      );
    } else {
      await firestore.cvRunTransaction((txn) async {
        txnSetEntityUserAccess(txn, newEntityId, userId, entityUserAccess);
      });
    }

    return newEntityId;
  }
}

/// Collection reference extension to generate unique id
extension TekartikCollectionReferenceUniqueId on CollectionReference {
  /// Safe unique id generation
  Future<String> noTxnGenerateUniqueId({
    String Function()? customGenerator,
  }) async {
    late String uniqueId;
    while (true) {
      uniqueId = customGenerator?.call() ?? AutoIdGenerator.autoId();
      var docSnapshot = await doc(uniqueId).get();
      if (!docSnapshot.exists) {
        break;
      }
    }
    return uniqueId;
  }
}
