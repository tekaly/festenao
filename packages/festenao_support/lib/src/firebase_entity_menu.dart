import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_support/festenao_build_menu_flutter.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// The festenao project the menu acts on, remembered between runs
/// (`fao_project` variable).
final kvFestenaoProject = 'fao_project'.kvFromVar();

/// Registers the dev menu items of one tkcms entity database, read through
/// [firebaseContext] (admin credentials: rules are bypassed, auth users are
/// listed, so this belongs in a support tool, never in an app).
///
/// Items, [entityName] being for example `project` or `calendar`:
/// - `list users`: the app level user access of [appId], when [appDb] and
///   [appId] are given;
/// - `list auth users`: the firebase auth users (at most [limit]);
/// - `list <entityName>s`: the entities of [entityDb] (at most [limit]);
/// - `current <entityName>`: the users and the sub collections of the
///   remembered entity, plus the items [entityMenu] adds for it;
/// - `select <entityName>`: picks the remembered entity;
/// - `vars`: the remembered entity id, [kvEntityId] (defaults to a
///   `<entityName>_id` variable).
void firebaseEntityMenu<T extends TkCmsFsEntity>({
  required FirebaseContext firebaseContext,
  required TkCmsFirestoreDatabaseServiceEntityAccess<T> entityDb,
  String entityName = 'entity',
  TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>? appDb,
  String? appId,
  KeyValue? kvEntityId,
  int limit = 50,
  void Function(T entity)? entityMenu,
}) {
  var firestore = firebaseContext.firestore;
  var kvEntity = kvEntityId ?? '${entityName}_id'.kvFromVar();
  var entities = '${entityName}s';

  Future<List<T>> listEntities() =>
      entityDb.fsEntityCollectionRef.query().limit(limit).get(firestore);

  if (appDb != null && appId != null) {
    item('list users', () async {
      var users = await appDb
          .fsEntityUserAccessCollectionRef(appId)
          .get(firestore);
      write('Users ${users.length}');
      for (var user in users) {
        write('- ${user.id}: $user');
      }
    });
  }
  item('list auth users', () async {
    var users = (await firebaseContext.auth.listUsers(maxResults: limit)).users;
    write('Users ${users.length}');
    for (var user in users) {
      if (user == null) {
        write('null user');
      } else {
        write(
          '- ${user.uid}: ${user.email}/${user.emailVerified} ${user.displayName} $user',
        );
      }
    }
  });
  item('list $entities', () async {
    var list = await listEntities();
    write(
      '${entities[0].toUpperCase()}${entities.substring(1)} ${list.length}',
    );
    for (var doc in list) {
      write('- ${doc.id}: $doc');
    }
  });
  item('current $entityName', () async {
    var entityId = kvEntity.value ?? '';
    if (entityId.isEmpty) {
      write('no $entityName selected, use \'select $entityName\' first');
      return;
    }
    write(entityId);
    var entity = await entityDb.fsEntityRef(entityId).get(firestore);
    if (!entity.exists) {
      write('$entityName $entityId not found');
    }
    await showMenu(() {
      item('list $entityName users', () async {
        var users = await entityDb
            .fsEntityUserAccessCollectionRef(entityId)
            .get(firestore);
        write('Users ${users.length}');
        for (var user in users) {
          write('- ${user.id}: $user');
        }
      });
      item('list collections', () async {
        var collections = await entityDb
            .fsEntityRef(entityId)
            .raw(firestore)
            .listCollections();
        write('Collections ${collections.length}');
        for (var coll in collections) {
          write('- ${coll.id}: $coll');
        }
      });
      if (entity.exists) {
        entityMenu?.call(entity);
      }
    });
  });
  item('select $entityName', () async {
    write('loading');
    var list = await listEntities();
    writeln(
      '${entities[0].toUpperCase()}${entities.substring(1)} ${list.length}',
    );
    await showMenu(() {
      for (var entity in list) {
        item('${entity.id} ${entity.name.v}', () {
          write(entity.toString());
          kvEntity.value = entity.id;
          popMenu();
        });
      }
    });
  });
  keyValuesMenu('vars', [kvEntity]);
}

/// The festenao firebase menu: app users, auth users and the projects of the
/// app of [appFlavorContext], read through [fbContext] (admin credentials).
///
/// [fsDatabase] defaults to a [FestenaoFirestoreDatabase] built on them. The
/// selected project is remembered in [kvFestenaoProject].
void firebaseFestenaoMenu(
  AppFlavorContext appFlavorContext,
  FirebaseContext fbContext, {
  FestenaoFirestoreDatabase? fsDatabase,
}) {
  fsDatabase ??= FestenaoFirestoreDatabase(
    firebaseContext: fbContext,
    flavorContext: appFlavorContext,
  );
  firebaseEntityMenu<FsProject>(
    firebaseContext: fbContext,
    entityDb: fsDatabase.projectDb,
    entityName: 'project',
    appDb: fsDatabase.appDb,
    appId: appFlavorContext.appId,
    kvEntityId: kvFestenaoProject,
  );
}
