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
    var newEntityId = await firestore.cvRunTransaction((txn) async {
      late String newEntityId;
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

    // Set access
    var entityUserAccess = TkCmsFsUserAccess()
      ..admin.v = true
      ..fixAccess();

    await firestore.cvRunTransaction((txn) async {
      txnSetEntityUserAccess(txn, newEntityId, userId, entityUserAccess);
    });

    return newEntityId;
  }

  /// Set (or delete when [access] is null) the access rights of another
  /// (invited) user on an entity.
  ///
  /// Must be called while signed in as the entity creator (or an existing
  /// admin), the only ones the rules allow to write the entity access
  /// documents.
  ///
  /// Both access documents (`entity_id/.../user_access/[userId]` and
  /// `user_id/[userId]/entity_access/...`) are written (or deleted) in a
  /// single transaction so they never get out of sync.
  Future<void> standaloneSetUserAccess({
    required String entityId,
    required String userId,
    TkCmsFsUserAccess? access,
  }) async {
    await firestore.cvRunTransaction((txn) async {
      if (access == null) {
        txnSetEntityUserAccess(txn, entityId, userId, null);
      } else {
        var userAccess = TkCmsFsUserAccess()..copyAccessFrom(access);
        txnSetEntityUserAccess(txn, entityId, userId, userAccess);
      }
    });
  }

  /// The public access document of an entity:
  /// `access/{entity}/entity_id/[entityId]/public_access/public`.
  ///
  /// Readable by anyone, only writable by an admin.
  CvDocumentReference<TkCmsFsPublicAccess> fsEntityPublicAccessRef(
    String entityId,
  ) => fsEntityUserAccessCollectionRef(entityId).parent!
      .collection<TkCmsFsPublicAccess>(tkCmsPublicAccessFirestorePathPart)
      .doc(tkCmsPublicAccessPublicDocumentId);

  /// Set (or delete when [access] is null) the public access of an entity.
  ///
  /// Must be called while signed in as an admin of the entity, the only ones
  /// the rules allow to write the public access document.
  ///
  /// Granting `read` makes the entity `data` sub collection readable by
  /// anyone, even without signing in.
  Future<void> standaloneSetPublicAccess({
    required String entityId,
    TkCmsFsPublicAccess? access,
  }) async {
    var ref = fsEntityPublicAccessRef(entityId);
    if (access == null) {
      await firestore.refDelete(ref);
    } else {
      await firestore.refSet(ref, access);
    }
  }

  /// Mark the entity as deleted then purge it (admin access needed).
  Future<void> standaloneDeleteAndPurge({
    required String userId,
    required String entityId,
  }) async {
    await deleteEntity(entityId, userId: userId);

    await purgeEntity(entityId, userId: userId);
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
